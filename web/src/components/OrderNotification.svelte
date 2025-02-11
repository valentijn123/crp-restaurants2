<script lang="ts">
    import { fly, slide } from 'svelte/transition';
    import { backOut } from 'svelte/easing';
    import { Clock } from 'lucide-svelte';
    import { Receive } from '@enums/events';
    import { ReceiveEvent } from '@utils/eventsHandlers';
    import { onMount } from 'svelte';

    type Order = {
        id: string;
        items: Array<{
            product: {
                id: number;
                name: string;
                price: number;
            };
            quantity: number;
        }>;
        total: number;
        timestamp: string;
        playerId: string;
        paymentMethod: 'cash' | 'bank';
    };

    let notifications: Order[] = [];
    const NOTIFICATION_DURATION = 8000;

    onMount(() => {
        function handleNewOrder(event: MessageEvent) {
            console.log('[DEBUG] OrderNotification received message:', event.data);
            
            let orderData = null;
            
            // Check voor NUI messages
            if (event.type === 'message' && event.data?.action === 'resource:newOrder' && event.data.data) {
                console.log('[DEBUG] Received NUI message:', event.data.data);
                orderData = {
                    ...event.data.data,
                    timestamp: new Date().toISOString()
                };
            }

            if (orderData && orderData.items && orderData.items.length > 0) {
                notifications = [orderData, ...notifications];
                
                setTimeout(() => {
                    notifications = notifications.filter(n => n.id !== orderData.id);
                }, NOTIFICATION_DURATION);
            }
        }

        // Alleen luisteren naar message events
        window.addEventListener('message', handleNewOrder);

        return () => {
            window.removeEventListener('message', handleNewOrder);
        };
    });
</script>

<div id="order-notifications" class="fixed top-4 right-4 z-[9999] flex flex-col gap-3 items-end">
    {#each notifications as order (order.id)}
        <div
            class="bg-[#1a1a1a] rounded-xl shadow-2xl w-[350px] overflow-hidden border border-[#2a2a2a]"
            in:fly={{ x: 50, duration: 300, easing: backOut }}
            out:fly={{ x: 50, duration: 200, delay: 300 }}
        >
            <!-- Header -->
            <div class="w-full p-4 bg-[#2a2a2a] border-b border-[#3a3a3a]">
                <div class="flex items-center gap-3">
                    <div class="bg-accent/10 w-10 h-10 rounded-xl flex items-center justify-center">
                        <Clock class="w-5 h-5 text-accent" />
                    </div>
                    <div class="flex-1">
                        <h2 class="text-xl font-bold text-white">#{order.id}</h2>
                        <p class="text-sm text-gray-400">Nieuwe bestelling</p>
                    </div>
                </div>
            </div>

            <!-- Producten -->
            <div 
                class="p-4"
                transition:slide|local={{ duration: 300, delay: 500 }}
            >
                {#each order.items as item, index}
                    <div 
                        class="flex items-center gap-3 py-2 first:pt-0 last:pb-0"
                        in:slide|local={{ duration: 200, delay: 700 + index * 100 }}
                        out:slide|local={{ duration: 200, delay: index * 50 }}
                    >
                        <div class="min-w-[32px] h-8 rounded-lg bg-accent/10 flex items-center justify-center">
                            <span class="text-sm font-medium text-accent">{item.quantity}x</span>
                        </div>
                        <span class="text-white font-medium">{item.product.name}</span>
                    </div>
                {/each}
            </div>
        </div>
    {/each}
</div> 