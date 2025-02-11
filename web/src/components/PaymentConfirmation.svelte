<script lang="ts">
    import { fade, scale } from 'svelte/transition';
    import { backOut } from 'svelte/easing';
    import { X, Check, Loader2 } from 'lucide-svelte';
    import { createEventDispatcher, onMount, onDestroy } from 'svelte';
    import { SendEvent } from '@utils/eventsHandlers';
    import toast from 'svelte-french-toast';
    
    const dispatch = createEventDispatcher();

    export let total: number = 0;
    export let businessName: string = "Restaurant Naam";
    export let paymentMethod: 'cash' | 'bank';
    export let currentBalance: number = 0;
    export let sourcePlayer: string;
    export let cart: any[] = [];
    
    let mounted = false;
    let isProcessing = false;
    let isClosing = false;
    
    $: formattedTotal = Number(total) || 0;
    $: formattedBalance = Number(currentBalance) || 0;

    const messageHandler = (event: MessageEvent) => {
        if (event.data?.action === 'resource:paymentProcessed') {
            const response = event.data.data;
            if (response && response.success) {
                setTimeout(() => {
                    isProcessing = false;
                    isClosing = true;

                    setTimeout(() => {
                        mounted = false;
                        setTimeout(() => {
                            dispatch('confirm');
                        }, 300);
                    }, 300);
                }, 1000);
            } else {
                isProcessing = false;
                isClosing = true;
                
                setTimeout(() => {
                    mounted = false;
                    setTimeout(() => {
                        dispatch('decline');
                    }, 300);
                }, 300);
            }
        } else if (event.data?.action === 'moneyResponse') {
            currentBalance = Number(event.data.data.balance) || 0;
        }
    };

    async function handlePaymentResponse(accepted: boolean) {
        if (isProcessing || isClosing) return;
        isProcessing = true;
        
        try {
            // Stuur direct een NUI callback
            fetch(`https://crp-restaurants/paymentResponse`, {
                method: 'POST',
                body: JSON.stringify({
                    sourcePlayer,
                    accepted,
                    total: formattedTotal,
                    businessName,
                    paymentMethod,
                    items: cart || []
                })
            });
            
            // De rest wordt afgehandeld door de message listener
        } catch (error) {
            console.error('Betaling mislukt:', error);
            toast.error('Er ging iets mis met de betaling');
            isProcessing = false;
        }
    }

    async function handleConfirm() {
        await handlePaymentResponse(true);
    }

    async function handleDecline() {
        await handlePaymentResponse(false);
    }

    function handleClose() {
        if (isClosing) return;
        isClosing = true;
        
        setTimeout(() => {
            mounted = false;
            setTimeout(() => {
                dispatch('close');
            }, 300);
        }, 300);
    }

    onMount(() => {
        console.log('[DEBUG] BetalingsBevestiging component gemount');
        mounted = true;
        SendEvent('getMoney', { 
            moneyType: paymentMethod 
        })
            .then(response => {
                currentBalance = Number(response.balance) || 0;
            })
            .catch(error => {
                console.error('Failed to fetch balance:', error);
                currentBalance = 0;
            });
        window.addEventListener('message', messageHandler);
    });

    onDestroy(() => {
        mounted = false;
        window.removeEventListener('message', messageHandler);
    });
</script>

{#if mounted}
    <div 
        class="fixed inset-0 bg-black/50 flex items-center justify-center z-[100]"
        transition:fade={{ duration: 200 }}
        on:click={handleClose}
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
            on:click|stopPropagation={() => {}}
        >
            <!-- Header -->
            <div class="p-6 border-b border-[#2a2a2a] flex items-center justify-between">
                <h2 class="text-xl font-bold text-white">Betalingsverzoek</h2>
                <button 
                    class="text-gray-400 hover:text-gray-300 transition-colors p-2 hover:bg-[#2a2a2a] rounded-lg"
                    on:click={handleClose}
                >
                    <X class="w-6 h-6" />
                </button>
            </div>

            <!-- Content -->
            <div class="p-6 space-y-6">
                <!-- Bedrag Banner -->
                <div class="bg-accent/10 rounded-xl p-6 text-center">
                    <p class="text-gray-400 mb-2">Te betalen bedrag</p>
                    <p class="text-4xl font-bold text-accent">${formattedTotal.toFixed(2)}</p>
                </div>

                <!-- Betalingsinfo -->
                <div class="space-y-4">
                    <!-- Betaalmethode -->
                    <div class="bg-[#2a2a2a] p-4 rounded-xl flex items-center gap-3">
                        <div class="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center">
                            {#if paymentMethod === 'cash'}
                                <span class="text-accent text-xl">€</span>
                            {:else}
                                <span class="text-accent text-xl">B</span>
                            {/if}
                        </div>
                        <div>
                            <p class="text-white font-medium">
                                {paymentMethod === 'cash' ? 'Contante Betaling' : 'Bankrekening'}
                            </p>
                            <p class="text-sm text-gray-400">
                                {paymentMethod === 'cash' ? 'Betaal aan de kassa' : 'Direct van je rekening'}
                            </p>
                        </div>
                    </div>

                    <!-- Saldo Info -->
                    <div class="bg-[#2a2a2a] p-4 rounded-xl">
                        <div class="flex justify-between items-center">
                            <span class="text-gray-400">Huidig Saldo</span>
                            <span class="text-white font-medium">${formattedBalance.toFixed(2)}</span>
                        </div>
                        <div class="flex justify-between items-center pt-3 border-t border-[#3a3a3a]">
                            <span class="text-gray-400">Na betaling</span>
                            {#if formattedBalance >= formattedTotal}
                                <span class="text-green-400 font-medium">
                                    ${(formattedBalance - formattedTotal).toFixed(2)}
                                </span>
                            {:else}
                                <span class="text-red-400 font-medium">
                                    Onvoldoende saldo (-${(formattedTotal - formattedBalance).toFixed(2)})
                                </span>
                            {/if}
                        </div>
                    </div>
                </div>
            </div>

            <!-- Actions -->
            <div class="p-6 border-t border-[#2a2a2a] flex gap-3">
                <button
                    on:click={handleDecline}
                    class="flex-1 py-3 rounded-xl bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors flex items-center justify-center gap-3 font-medium"
                    disabled={isProcessing}
                >
                    <X class="w-5 h-5" />
                    Weigeren
                </button>
                <button
                    on:click={handleConfirm}
                    class="flex-1 py-3 rounded-xl bg-green-500/10 text-green-400 hover:bg-green-500/20 transition-colors flex items-center justify-center gap-3 font-medium"
                    disabled={isProcessing}
                >
                    {#if isProcessing}
                        <Loader2 class="w-5 h-5 animate-spin" />
                    {:else}
                        <Check class="w-5 h-5" />
                        Bevestigen
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if} 