<script lang="ts">
    import { fade, scale, slide } from 'svelte/transition';
    import { backOut, quintOut } from 'svelte/easing';
    import { createEventDispatcher } from 'svelte';
    import { X, ChevronDown, Loader2, Wallet, CreditCard, Check } from 'lucide-svelte';
    import { Send, Receive } from '@enums/events';
    import { SendEvent, ReceiveEvent } from '@utils/eventsHandlers';
    import { onMount, onDestroy } from 'svelte';

    const dispatch = createEventDispatcher();

    console.log('[DEBUG] Send enum values:', Send);

    export let total: number;
    
    let selectedPlayerId: string = '';
    let paymentMethod: 'cash' | 'bank' = 'cash';
    let isDropdownOpen = false;
    let isProcessing = false;
    let isCompleted = false;
    let nearbyPlayers: Array<{ id: string, name: string }> = [];
    let paymentStatus: 'pending' | 'success' | 'failed' = 'pending';
    let paymentMessage = '';

    // Request nearby players when component mounts
    SendEvent('getNearbyPlayers');

    // Listen for nearby players updates
    window.addEventListener('message', (event) => {
        if (event.data?.action === 'resource:nearbyPlayers') {
            console.log('[DEBUG] Received nearby players event');
            console.log('[DEBUG] Full event data:', event.data);
            console.log('[DEBUG] Players array:', event.data.data.players);
            nearbyPlayers = event.data.data.players;
            console.log('[DEBUG] Updated nearbyPlayers after update:', nearbyPlayers);
        }
    });

    // Add this event listener near your other window.addEventListener
    window.addEventListener('message', (event) => {
        if (event.data?.action === 'resource:showPaymentConfirmation') {
            console.log('[DEBUG] Showing payment confirmation:', event.data);
            const paymentData = event.data.data;
            
            const modal = new PaymentConfirmation({
                target: document.body,
                props: {
                    total: paymentData.total,
                    businessName: paymentData.businessName,
                    paymentMethod: paymentData.paymentMethod,
                    sourcePlayer: paymentData.sourcePlayer
                }
            });

            modal.$on('confirm', () => {
                SendEvent('confirmPayment', {
                    sourcePlayer: paymentData.sourcePlayer,
                    accepted: true
                });
                modal.$destroy();
            });

            modal.$on('decline', () => {
                SendEvent('confirmPayment', {
                    sourcePlayer: paymentData.sourcePlayer,
                    accepted: false
                });
                modal.$destroy();
            });

            modal.$on('close', () => {
                SendEvent('confirmPayment', {
                    sourcePlayer: paymentData.sourcePlayer,
                    accepted: false
                });
                modal.$destroy();
            });
        }
    });

    let messageHandler = (event) => {
        if (!event.data?.action) return;
        if (event.data.action !== 'resource:paymentProcessed') return;
        
        console.log('[DEBUG] Payment processed:', event.data);
        
        const response = event.data.data;
        paymentStatus = response.success ? 'success' : 'failed';
        paymentMessage = response.message || (response.success 
            ? 'Betaling succesvol verwerkt!'
            : 'Betaling geweigerd door klant');
        
        if (response.success) {
            setTimeout(() => {
                dispatch('submit', { 
                    playerId: selectedPlayerId, 
                    paymentMethod, 
                    total 
                });
                isProcessing = false;
            }, 3000);
        } else {
            setTimeout(() => {
                isProcessing = false;
                paymentStatus = 'pending';
            }, 3000);
        }
    };

    onMount(() => {
        window.addEventListener('message', messageHandler);
    });

    onDestroy(() => {
        window.removeEventListener('message', messageHandler);
    });

    async function handleSubmit() {
        if (!selectedPlayerId || isProcessing) return;
        
        isProcessing = true;
        paymentStatus = 'pending';
        
        try {
            await SendEvent('requestPayment', {
                playerId: selectedPlayerId,
                total,
                paymentMethod,
                businessName: 'Burgershot'
            });
        } catch (error) {
            console.error('Payment failed:', error);
            paymentStatus = 'failed';
            paymentMessage = 'Betaling mislukt';
            setTimeout(() => {
                isProcessing = false;
                paymentStatus = 'pending';
            }, 3000);
        }
    }

    function handleCancel() {
        isProcessing = false;
        isCompleted = false;
    }

    // Sluit dropdown als er buiten wordt geklikt
    function handleClickOutside(event: MouseEvent) {
        const target = event.target as HTMLElement;
        if (!target.closest('.dropdown')) {
            isDropdownOpen = false;
        }
    }
</script>

<svelte:window on:click={handleClickOutside} />

<div 
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-[100]"
    transition:fade={{ duration: 200 }}
>
    <div
        class="bg-[#1a1a1a] w-[450px] rounded-xl shadow-2xl"
        in:scale={{
            duration: 300,
            delay: 100,
            start: 0.95,
            opacity: 0,
            easing: backOut
        }}
        out:scale={{
            duration: 200,
            start: 1,
            opacity: 0,
            easing: backOut
        }}
    >
        <div class="p-6 border-b border-[#2a2a2a] flex items-center justify-between">
            <h2 class="text-xl font-bold text-white">Transactie Afronden</h2>
            <button 
                class="text-gray-400 hover:text-gray-300 transition-colors p-2 hover:bg-[#2a2a2a] rounded-lg"
                on:click={() => dispatch('close')}
            >
                <X class="w-6 h-6" />
            </button>
        </div>

        <div class="p-6 space-y-8">
            <!-- Totaal Bedrag Banner -->
            <div class="bg-accent/10 rounded-xl p-6 text-center">
                <p class="text-gray-400 mb-2 text-lg">Totaal Bedrag</p>
                <p class="text-4xl font-bold text-accent">${total.toFixed(2)}</p>
            </div>

            <!-- Speler Selectie -->
            <div class="space-y-3">
                <label class="text-sm text-gray-400 font-medium">Selecteer Speler</label>
                <div class="relative dropdown">
                    <button
                        class="w-full px-4 py-4 bg-[#2a2a2a] rounded-xl text-left flex items-center justify-between hover:bg-[#3a3a3a] transition-colors ring-1 ring-white/5"
                        on:click={() => isDropdownOpen = !isDropdownOpen}
                    >
                        <span class="text-white text-lg">
                            {selectedPlayerId ? nearbyPlayers.find(p => p.id === selectedPlayerId)?.name : 'Kies een speler...'}
                        </span>
                        <ChevronDown class="w-6 h-6 text-gray-400 transition-transform duration-200" 
                            style="transform: rotate({isDropdownOpen ? '180deg' : '0deg'})"
                        />
                    </button>
                    
                    {#if isDropdownOpen}
                        <div 
                            class="absolute top-full left-0 right-0 mt-2 bg-[#2a2a2a] rounded-xl overflow-hidden shadow-xl ring-1 ring-white/5 z-[101]"
                            transition:slide={{ duration: 200, easing: quintOut }}
                        >
                            {#each nearbyPlayers as player}
                                <button
                                    class="w-full px-4 py-4 text-left text-white hover:bg-[#3a3a3a] transition-colors flex items-center gap-3"
                                    class:bg-accent={selectedPlayerId === player.id}
                                    on:click={() => {
                                        selectedPlayerId = player.id;
                                        isDropdownOpen = false;
                                    }}
                                >
                                    <div class="w-10 h-10 rounded-full flex items-center justify-center text-lg font-medium shrink-0
                                        {selectedPlayerId === player.id ? 'bg-white/20 text-white' : 'bg-accent/10 text-accent'}"
                                    >
                                        {player.name[0]}
                                    </div>
                                    <span class="text-lg">{player.name}</span>
                                </button>
                            {/each}
                        </div>
                    {/if}
                </div>
            </div>

            <!-- Betaalmethode -->
            <div class="space-y-3">
                <label class="text-sm text-gray-400 font-medium">Betaalmethode</label>
                <div class="grid grid-cols-2 gap-3">
                    <button
                        class="px-4 py-4 rounded-xl text-white transition-colors flex items-center justify-center gap-3 ring-1 ring-white/5 text-lg"
                        class:bg-accent={paymentMethod === 'cash'}
                        class:bg-[#2a2a2a]={paymentMethod !== 'cash'}
                        class:ring-accent={paymentMethod === 'cash'}
                        on:click={() => paymentMethod = 'cash'}
                    >
                        <Wallet class="w-7 h-7" />
                        Contant
                    </button>
                    <button
                        class="px-4 py-4 rounded-xl text-white transition-colors flex items-center justify-center gap-3 ring-1 ring-white/5 text-lg"
                        class:bg-accent={paymentMethod === 'bank'}
                        class:bg-[#2a2a2a]={paymentMethod !== 'bank'}
                        class:ring-accent={paymentMethod === 'bank'}
                        on:click={() => paymentMethod = 'bank'}
                    >
                        <CreditCard class="w-7 h-7" />
                        Bank
                    </button>
                </div>
            </div>
        </div>

        <div class="p-6 border-t border-[#2a2a2a]">
            {#if isProcessing}
                <div class="space-y-3">
                    <div 
                        class="flex items-center justify-center gap-3 p-4 rounded-xl"
                        class:bg-[#2a2a2a]={paymentStatus === 'pending'}
                        class:bg-[#22c55e1a]={paymentStatus === 'success'}
                        class:bg-[#ef44441a]={paymentStatus === 'failed'}
                    >
                        {#if paymentStatus === 'pending'}
                            <Loader2 class="w-7 h-7 animate-spin text-white" />
                            <span class="text-lg text-white">Wachten op betaling...</span>
                        {:else if paymentStatus === 'success'}
                            <Check class="w-7 h-7 text-green-400" />
                            <span class="text-lg text-green-400">{paymentMessage}</span>
                        {:else}
                            <X class="w-7 h-7 text-red-400" />
                            <span class="text-lg text-red-400">{paymentMessage}</span>
                        {/if}
                    </div>

                    {#if paymentStatus === 'pending'}
                        <button
                            on:click={handleCancel}
                            class="w-full bg-red-500/10 hover:bg-red-500/20 text-red-400 py-4 rounded-xl font-medium transition-colors text-lg"
                            in:scale={{
                                duration: 200,
                                start: 0.95,
                                opacity: 0,
                                easing: backOut
                            }}
                        >
                            Betaling Annuleren
                        </button>
                    {/if}
                </div>
            {:else}
                <button
                    on:click={handleSubmit}
                    disabled={!selectedPlayerId}
                    class="w-full bg-accent hover:bg-accent/90 text-white py-4 rounded-xl font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 text-lg"
                >
                    Bevestig Transactie
                </button>
            {/if}
        </div>
    </div>
</div> 