<script lang="ts">
    import { fade, scale, slide } from 'svelte/transition';
    import { backOut } from 'svelte/easing';
    import { Check, X, ChevronDown, ChevronUp, Clock, CreditCard, Wallet } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import { Receive } from '@enums/events';
    import { ReceiveEvent } from '@utils/eventsHandlers';
    import { onMount } from 'svelte';

    const dispatch = createEventDispatcher();
    let mounted = false;

    function formatOrder(order: any) {
        return {
            ...order,
            id: Number(order.id),
            timestamp: new Date(order.timestamp).toISOString(),
            status: order.status || 'pending'
        };
    }

    // Message handler aanpassen
    function handleMessage(event: MessageEvent) {
        if (event.data?.action === 'resource:showOrderReceiver') {
            mounted = true;
            // Controleer of orders bestaat voordat we gaan mappen
            orders = event.data.data?.orders ? event.data.data.orders.map(formatOrder) : [];
        } else if (event.data?.action === 'resource:newOrder' && event.data.data) {
            orders = [...orders, formatOrder(event.data.data)];
        } else if (event.data?.action === 'resource:activeOrdersResponse' && event.data.data) {
            orders = event.data.data.map(formatOrder);
        } else if (event.data?.action === 'resource:orderStatusUpdated' && event.data.data) {
            const { orderId, status } = event.data.data;
            orders = orders.map(order => 
                order.id === Number(orderId) ? { ...order, status } : order
            );
        }
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            handleClose();
        }
    }

    onMount(() => {
        window.addEventListener('message', handleMessage);
        window.addEventListener('keydown', handleKeydown);
        
        // Haal actieve orders op bij mount
        fetch('https://crp-restaurants/getActiveOrders', {
            method: 'POST'
        });
        
        return () => {
            window.removeEventListener('message', handleMessage);
            window.removeEventListener('keydown', handleKeydown);
        };
    });

    async function handleClose() {
        console.log('handleClose called');
        try {
            await fetch('https://crp-restaurants/closeOrderReceiver', {
                method: 'POST'
            });
            mounted = false;
        } catch (error) {
            console.error('Failed to close order receiver:', error);
        }
    }

    type Order = {
        id: number;
        items: Array<{
            product: {
                id: number;
                name: string;
                price: number;
            };
            quantity: number;
            notes?: string;
        }>;
        total: number;
        timestamp: string;
        status: 'pending' | 'completed' | 'cancelled';
        playerId: string;
        paymentMethod: 'cash' | 'bank';
    };

    // Update de orders array (leeg bij start)
    let orders: Order[] = [];

    let expandedOrders: Set<string> = new Set();

    function toggleOrder(orderId: string) {
        console.log('toggleOrder called with:', orderId);
        const target = event?.target as HTMLElement;
        console.log('Click target:', target);
        
        const newExpanded = new Set(expandedOrders);
        if (newExpanded.has(orderId)) {
            newExpanded.delete(orderId);
        } else {
            newExpanded.add(orderId);
        }
        expandedOrders = newExpanded;
    }

    function getTimeAgo(timestamp: string): string {
        const minutes = Math.floor((Date.now() - new Date(timestamp).getTime()) / 60000);
        if (minutes < 1) return 'Zojuist';
        if (minutes === 1) return '1 minuut geleden';
        return `${minutes} minuten geleden`;
    }
</script>

{#if mounted}
    <div 
        class="fixed inset-0 bg-black/50 flex items-center justify-center"
        style="z-index: 9999;"
        transition:fade={{ duration: 200 }}
        on:click|self={handleClose}
    >
        <div 
            class="bg-[#1a1a1a] w-[500px] rounded-xl shadow-2xl flex flex-col max-h-[80vh] relative"
            style="z-index: 10000;"
            transition:scale={{ 
                duration: 300, 
                start: 0.95, 
                opacity: 0, 
                easing: backOut 
            }}
        >
            <div class="p-6 border-b border-[#2a2a2a] flex items-center justify-between relative z-10">
                <h2 class="text-xl font-bold text-white">Inkomende Bestellingen</h2>
                <button 
                    on:click={handleClose}
                    class="text-gray-400 hover:text-gray-300 transition-colors p-2 hover:bg-[#2a2a2a] rounded-lg relative z-10"
                >
                    <X class="w-6 h-6" />
                </button>
            </div>

            <div class="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-[#2a2a2a] scrollbar-track-transparent hover:scrollbar-thumb-[#3a3a3a]">
                {#if orders.length === 0}
                    <div class="p-8 text-center text-gray-400">
                        <div class="bg-[#2a2a2a] w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4">
                            <Clock class="w-8 h-8 text-accent/80" />
                        </div>
                        <p class="text-lg font-medium text-white mb-1">Geen actieve bestellingen</p>
                        <p class="text-sm text-gray-400">Nieuwe bestellingen verschijnen hier</p>
                    </div>
                {:else}
                    {#each [...orders].reverse() as order (order.id)}
                        <div 
                            class="border-b border-[#2a2a2a] last:border-0"
                        >
                            <button
                                class="w-full p-4 hover:bg-[#2a2a2a] transition-colors relative z-10"
                                on:click={() => toggleOrder(order.id.toString())}
                            >
                                <div class="flex items-center justify-between mb-2">
                                    <div>
                                        <p class="text-white font-medium">Bestelling #{order.id}</p>
                                        <div class="flex items-center gap-2 text-sm text-gray-400">
                                            <Clock class="w-4 h-4" />
                                            {getTimeAgo(order.timestamp)}
                                            {#if order.paymentMethod === 'bank'}
                                                <CreditCard class="w-4 h-4 ml-2" />
                                            {:else}
                                                <Wallet class="w-4 h-4 ml-2" />
                                            {/if}
                                        </div>
                                    </div>
                                    <div class="flex items-center gap-3">
                                        <span class="text-accent font-bold">${order.total.toFixed(2)}</span>
                                        {#if expandedOrders.has(order.id.toString())}
                                            <ChevronUp class="w-5 h-5 text-gray-400" />
                                        {:else}
                                            <ChevronDown class="w-5 h-5 text-gray-400" />
                                        {/if}
                                    </div>
                                </div>
                            </button>

                            {#if expandedOrders.has(order.id.toString())}
                                <div 
                                    class="px-4 pb-4 relative z-0"
                                    transition:slide|local={{ 
                                        duration: 300,
                                        easing: backOut
                                    }}
                                >
                                    <div 
                                        class="bg-[#2a2a2a] rounded-xl p-4"
                                        in:scale|local={{ 
                                            duration: 200,
                                            delay: 100,
                                            start: 0.98,
                                            opacity: 0,
                                            easing: backOut 
                                        }}
                                    >
                                        {#each order.items as item}
                                            <div class="flex items-center justify-between py-2 first:pt-0 last:pb-0 border-b border-[#3a3a3a] last:border-0">
                                                <div class="flex items-center gap-2">
                                                    <div class="min-w-[40px] h-10 rounded-lg bg-accent/10 flex items-center justify-center">
                                                        <span class="text-base font-medium text-accent">{item.quantity}x</span>
                                                    </div>
                                                    <div>
                                                        <span class="text-white">{item.product.name}</span>
                                                        {#if item.notes}
                                                            <p class="text-sm text-gray-400">{item.notes}</p>
                                                        {/if}
                                                    </div>
                                                </div>
                                                <span class="text-accent">${(item.product.price * item.quantity).toFixed(2)}</span>
                                            </div>
                                        {/each}
                                    </div>

                                    <div 
                                        class="flex gap-2 mt-4"
                                        in:scale|local={{ 
                                            duration: 200,
                                            delay: 150,
                                            start: 0.98,
                                            opacity: 0,
                                            easing: backOut 
                                        }}
                                    >
                                        <button 
                                            class="flex-1 py-3 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors flex items-center justify-center gap-3 font-medium"
                                        >
                                            <X class="w-5 h-5" />
                                            Annuleren
                                        </button>
                                        <button 
                                            class="flex-1 py-3 rounded-lg bg-green-500/10 text-green-400 hover:bg-green-500/20 transition-colors flex items-center justify-center gap-3 font-medium"
                                        >
                                            <Check class="w-5 h-5" />
                                            Voltooien
                                        </button>
                                    </div>
                                </div>
                            {/if}
                        </div>
                    {/each}
                {/if}
            </div>
        </div>
    </div>
{/if}