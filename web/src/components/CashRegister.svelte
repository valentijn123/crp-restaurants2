<script lang="ts">
    import type { Product, Category } from '../types/product';
    import { Receive, Send } from '@enums/events';
    import { ReceiveEvent, SendEvent } from '@utils/eventsHandlers';
    import { onMount } from 'svelte';
    import { fade, scale, fly, slide } from 'svelte/transition';
    import { backOut, quintOut } from 'svelte/easing';
    import { flip } from 'svelte/animate';
    import { ShoppingCart, X, Plus, Minus, CreditCard, Search } from 'lucide-svelte';
    import toast from 'svelte-french-toast';
    import { twMerge } from 'tailwind-merge';
    import { tweened } from 'svelte/motion';
    import { cubicOut } from 'svelte/easing';
    import TransactionModal from './TransactionModal.svelte';
    // State
    let selectedCategory: string = 'all';
    let searchQuery = '';
    let cart: { product: Product; quantity: number; notes?: string; isNew: boolean }[] = [];
    
    // Restaurant specifieke categorieën
    let categories: Category[] = [{ id: 'all', name: 'Alles' }];
    let products: Product[] = [];
    let currentBusiness = '';

    function addItem(product: Product) {
        cart = cart.map(item => ({...item, isNew: false})); // Reset alle animaties eerst
        
        const existing = cart.find((item) => item.product.id === product.id);
        if (existing) {
            cart = cart.map(item => 
                item.product.id === product.id 
                    ? {...item, quantity: item.quantity + 1}
                    : item
            );
        } else {
            cart = [...cart, { product, quantity: 1, isNew: true }];
        }
        toast.success(`${product.name} toegevoegd`, {
            duration: 1000,
            position: 'bottom-right'
        });
    }

    function updateNotes(productId: number, notes: string) {
        cart = cart.map(item => 
            item.product.id === productId 
                ? { ...item, notes } 
                : item
        );
    }

    function removeItem(productId: number) {
        cart = cart.filter((item) => item.product.id !== productId);
    }

    function updateQuantity(productId: number, newQuantity: number) {
        if (newQuantity < 1) return;
        cart = cart.map(item => 
            item.product.id === productId 
                ? { ...item, quantity: newQuantity }
                : item
        );
    }

    // Tweened store voor het totaalbedrag
    const animatedTotal = tweened(0, {
        duration: 300,
        easing: cubicOut
    });

    // Optimaliseer calculateTotal met memoization
    let lastCart = [];
    let cachedTotal = 0;

    function calculateTotal() {
        if (JSON.stringify(lastCart) === JSON.stringify(cart)) {
            return cachedTotal;
        }
        
        lastCart = [...cart];
        cachedTotal = cart.reduce((total, item) => 
            total + (item.product.price * item.quantity), 0
        );
        return cachedTotal;
    }

    // Update het geanimeerde totaal wanneer de cart verandert
    $: {
        const total = calculateTotal();
        console.log('Cart:', cart);
        console.log('Total:', total);
        animatedTotal.set(total);
    }

    let showTransactionModal = false;
    let mounted = false;
    let productsLoaded = false;
    let shouldShow = false;

    // Reactive statement om mounted te updaten
    $: {
        if (productsLoaded && shouldShow) {
            console.log('[DEBUG] Products loaded and should show, mounting UI');
            mounted = true;
        } else if (!shouldShow) {
            console.log('[DEBUG] Should not show, unmounting UI');
            mounted = false;
        }
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            if (showTransactionModal) {
                showTransactionModal = false;
            } else {
                mounted = false;
            }
        }
    }

    onMount(() => {
        console.log('[DEBUG] CashRegister component mounted');
        
        // Stel shouldShow in op true bij het mounten
        shouldShow = true;

        // Direct bij het mounten een verzoek sturen voor de producten
        SendEvent(Send.getProducts).then((response) => {
            if (response.products) {
                products = response.products;
                productsLoaded = true;
                console.log('[DEBUG] Products loaded from direct response:', products);
            }
            if (response.categories) {
                categories = response.categories;
                console.log('[DEBUG] Categories loaded from direct response:', categories);
            }
        });
        
        const handleMessage = (event: MessageEvent) => {
            console.log('[DEBUG] Received message:', event);
            
            if (event.data?.action === Receive.visible) {
                const data = event.data.data;
                console.log('[DEBUG] Processing visible event:', data);
                
                if (data.show === true) {
                    shouldShow = true;
                    
                    // Update categories
                    if (Array.isArray(data.categories)) {
                        categories = data.categories;
                        console.log('[DEBUG] Updated categories:', categories);
                    }
                    
                    // Update products
                    if (Array.isArray(data.products)) {
                        products = data.products;
                        console.log('[DEBUG] Updated products:', products);
                        productsLoaded = true;
                    }
                } else if (data.show === false) {
                    console.log('[DEBUG] Hiding UI');
                    shouldShow = false;
                }
            }
        };

        window.addEventListener('message', handleMessage);
        window.addEventListener('keydown', handleKeydown);
        
        // Haal de huidige business op
        SendEvent(Send.getCurrentBusiness).then((response) => {
            if (response.business) {
                currentBusiness = response.business;
                console.log('[DEBUG] Huidige zaak:', currentBusiness);
            }
        });
        
        return () => {
            window.removeEventListener('message', handleMessage);
            window.removeEventListener('keydown', handleKeydown);
        };
    });

    async function handleCheckout() {
        if (cart.length === 0) return;
        console.log('[DEBUG] handleCheckout called');

        const orderData = {
            items: cart.map(item => ({
                product: {
                    id: item.product.id,
                    name: item.product.name,
                    price: item.product.price
                },
                quantity: item.quantity,
                notes: item.notes
            })),
            total: calculateTotal(),
            timestamp: new Date().toISOString(),
            businessName: currentBusiness || 'Burgershot'
        };

        console.log('[DEBUG] Bestelling voorbereid:', JSON.stringify(orderData));

        try {
            // Direct fetch gebruiken
            await fetch('https://crp-restaurants/checkout', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(orderData)
            });
            
            showTransactionModal = true;
        } catch (error) {
            console.error('[ERROR] Failed to send checkout event:', error);
            toast.error('Er ging iets mis bij het afronden van de bestelling');
        }
    }

    async function handleTransactionSubmit(event: CustomEvent) {
        const { playerId, paymentMethod } = event.detail;
        
        // Maak een kopie van de cart met de juiste structuur
        const orderItems = cart.map(item => ({
            product: {
                id: item.product.id,
                name: item.product.name,
                price: item.product.price
            },
            quantity: item.quantity,
            notes: item.notes
        }));

        const orderData = { 
            sourcePlayer: playerId,
            total: calculateTotal(),
            businessName: currentBusiness || 'Burgershot',
            paymentMethod,
            items: orderItems,
            accepted: true
        };

        try {
            await fetch('https://crp-restaurants/paymentResponse', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(orderData)
            });
        } catch (error) {
            console.error('[ERROR] Failed to submit transaction:', error);
            toast.error('Er ging iets mis bij het verwerken van de betaling');
        }
    }

    function clearCart() {
        cart.forEach((item, index) => {
            setTimeout(() => {
                cart = cart.filter(i => i !== item);
            }, index * 50);
        });
    }

    // Filter producten op basis van zoekopdracht en categorie
    $: filteredProducts = products
        .filter(p => selectedCategory === 'all' || p.category === selectedCategory)
        .filter(p => p.name.toLowerCase().includes(searchQuery.toLowerCase()));

    // Voeg deze console.log toe na de import statements
    console.log('[DEBUG] TransactionModal component:', TransactionModal);


    // Luister naar payment processed event
    onMount(() => {
        const handlePaymentProcessed = (event: MessageEvent) => {
            if (event.data?.action === 'resource:paymentProcessed') {
                const response = event.data.data;
                if (response && response.success) {
                    toast.success('Betaling succesvol verwerkt!');
                    // Wacht met sluiten tot de success message is getoond
                    setTimeout(() => {
                        showTransactionModal = false;
                    }, 3000); // Zelfde timing als in TransactionModal
                } else {
                    toast.error(response?.message || 'Betaling geweigerd');
                }
            }
        };

        window.addEventListener('message', handlePaymentProcessed);
        return () => window.removeEventListener('message', handlePaymentProcessed);
    });
</script>

{#if mounted}
    <div 
        class="fixed inset-0 flex items-center justify-center bg-black/50"
        transition:fade={{ duration: 200 }}
    >
        <div 
            class="bg-[#1a1a1a] rounded-xl shadow-2xl flex overflow-hidden w-[1200px] h-[800px]" 
            in:scale={{
                duration: 400,
                delay: 200,
                opacity: 0,
                start: 0.95,
                easing: backOut
            }}
            out:scale={{
                duration: 200,
                opacity: 0,
                start: 0.95
            }}
        >
            <!-- Linker kolom (Producten) -->
            <div 
                class="flex-1 flex flex-col min-w-0"
                in:fly={{ x: -20, duration: 400, delay: 400 }}
            >
                <!-- Zoekbalk -->
                <div class="p-4 border-b border-[#2a2a2a] bg-[#1f1f1f]">
                    <div class="relative mb-3 flex items-center">
                        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 pointer-events-none" />
                        <input
                            type="text"
                            bind:value={searchQuery}
                            placeholder="Zoek producten..."
                            class="w-full pl-10 pr-4 py-2 bg-[#2a2a2a] rounded-lg focus:outline-none focus:ring-2 focus:ring-accent"
                        />
                    </div>
                    
                    <!-- Categorieën -->
                    <div class="flex gap-2 overflow-x-auto no-scrollbar">
                        {#each categories as category}
                            <button 
                                class={twMerge(
                                    "px-4 py-2 rounded-lg whitespace-nowrap transition-colors",
                                    selectedCategory === category.id 
                                        ? "bg-accent text-white" 
                                        : "bg-[#2a2a2a] text-gray-300 hover:bg-[#3a3a3a]"
                                )}
                                on:click={() => selectedCategory = category.id}
                            >
                                {category.name}
                            </button>
                        {/each}
                    </div>
                </div>

                <!-- Product Grid met verbeterde animaties -->
                <div class="flex-1 overflow-y-auto p-4 grid grid-cols-3 gap-3 auto-rows-max">
                    {#each filteredProducts as product (product.id)}
                        <div
                            animate:flip={{
                                duration: 150,
                                easing: quintOut
                            }}
                        >
                            <button
                                class="bg-[#2a2a2a] rounded-xl p-3 hover:scale-[1.02] transition-all text-left hover:bg-[#2d2d2d] flex flex-col h-full w-full"
                                on:click={() => addItem(product)}
                                in:scale={{
                                    duration: 100,
                                    start: 0.98,
                                    opacity: 0.8,
                                    easing: backOut
                                }}
                                out:scale={{
                                    duration: 75,
                                    start: 0.98,
                                    opacity: 0
                                }}
                            >
                                <img 
                                    src={product.image} 
                                    alt={product.name}
                                    class="w-full aspect-square object-cover rounded-lg mb-2"
                                />
                                <div class="flex-1">
                                    <h3 class="font-bold text-white">{product.name}</h3>
                                    <p class="text-accent font-medium">${product.price.toFixed(2)}</p>
                                </div>
                            </button>
                        </div>
                    {/each}
                </div>
            </div>

            <!-- Rechter kolom (Winkelwagen) -->
            <div 
                class="w-[350px] border-l border-[#2a2a2a] flex flex-col bg-[#1f1f1f]"
                in:fly={{ x: 20, duration: 400, delay: 400 }}
            >
                <div 
                    class="p-4 border-b border-[#2a2a2a] flex items-center justify-between"
                    in:fly={{ y: -20, duration: 400, delay: 500 }}
                >
                    <h2 class="text-lg font-bold text-white flex items-center gap-2">
                        <ShoppingCart class="w-5 h-5" />
                        Huidige Bestelling
                    </h2>
                    {#if cart.length > 0}
                        <button 
                            on:click={clearCart}
                            class="text-red-400 hover:text-red-300 transition-colors"
                        >
                            <X class="w-5 h-5" />
                        </button>
                    {/if}
                </div>

                <!-- Winkelwagen inhoud -->
                <div class="flex-1 overflow-y-auto overflow-x-hidden p-4">
                    {#if cart.length === 0}
                        <div 
                            class="h-full flex flex-col items-center justify-center"
                            in:scale={{
                                duration: 300,
                                start: 0.95,
                                opacity: 0,
                                easing: backOut
                            }}
                        >
                            <div class="flex flex-col items-center">
                                <div class="bg-[#2a2a2a] p-6 rounded-2xl shadow-lg mb-4">
                                    <ShoppingCart class="w-14 h-14 text-accent/80" />
                                </div>
                                <h3 class="text-xl font-medium text-white mb-2">Winkelwagen is leeg</h3>
                                <p class="text-base text-gray-400 mb-6">Klik op producten om ze toe te voegen</p>
                            </div>
                        </div>
                    {:else}
                        {#each cart as item, i (item.product.id)}
                            <div 
                                class="bg-[#2a2a2a] rounded-xl p-3 mb-3 {item.isNew ? 'animate-pop' : ''}"
                                in:scale={{
                                    duration: 300,
                                    start: 0.6,
                                    opacity: 0,
                                    easing: backOut
                                }}
                                out:scale={{
                                    duration: 200,
                                    opacity: 0,
                                    start: 0.95
                                }}
                                animate:flip={{
                                    duration: 200
                                }}
                            >
                                <div class="flex items-center gap-3">
                                    <img 
                                        src={item.product.image} 
                                        alt={item.product.name}
                                        class="w-16 h-16 rounded-lg object-cover"
                                    />
                                    <div class="flex-1">
                                        <h3 class="font-medium text-white">{item.product.name}</h3>
                                        <p class="text-accent font-medium">${(item.product.price * item.quantity).toFixed(2)}</p>
                                    </div>
                                    <div class="flex items-center gap-2">
                                        <button 
                                            on:click={() => updateQuantity(item.product.id, item.quantity - 1)}
                                            class="p-1.5 rounded-lg hover:bg-[#3a3a3a] transition-colors"
                                        >
                                            <Minus class="w-4 h-4" />
                                        </button>
                                        <input
                                            type="number"
                                            min="1"
                                            bind:value={item.quantity}
                                            class="w-12 text-center bg-[#2a2a2a] rounded-lg py-1.5 focus:outline-none focus:ring-2 focus:ring-accent appearance-none"
                                        />
                                        <button 
                                            on:click={() => updateQuantity(item.product.id, item.quantity + 1)}
                                            class="p-1.5 rounded-lg hover:bg-[#3a3a3a] transition-colors"
                                        >
                                            <Plus class="w-4 h-4" />
                                        </button>
                                    </div>
                                    <button 
                                        on:click={() => removeItem(item.product.id)}
                                        class="text-red-400 hover:text-red-300 transition-colors"
                                    >
                                        <X class="w-5 h-5" />
                                    </button>
                                </div>
                                <input
                                    type="text"
                                    placeholder="Notities..."
                                    class="mt-2 w-full px-3 py-1.5 bg-[#3a3a3a] rounded-lg text-white placeholder-gray-400"
                                    bind:value={item.notes}
                                    on:input={(e) => updateNotes(item.product.id, e.currentTarget.value)}
                                />
                            </div>
                        {/each}
                    {/if}
                </div>

                <!-- Totaal en checkout knop -->
                <div 
                    class="p-4 border-t border-[#2a2a2a] bg-[#1f1f1f]"
                    in:fly={{ y: 20, duration: 400, delay: 500 }}
                >
                    <div class="flex items-center justify-between mb-3">
                        <h3 class="font-bold text-white">Totaal</h3>
                        <p class="text-accent text-xl font-bold">${$animatedTotal.toFixed(2)}</p>
                    </div>
                    <button 
                        on:click={handleCheckout}
                        class="w-full bg-accent hover:bg-accent/90 text-white py-3 rounded-xl flex items-center justify-center gap-2 font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        disabled={cart.length === 0}
                    >
                        <CreditCard class="w-5 h-5" />
                        Bestelling Afronden
                    </button>
                </div>
            </div>
        </div>
    </div>
{/if}

{#if showTransactionModal}
    <TransactionModal
        total={calculateTotal()}
        on:close={() => showTransactionModal = false}
        on:submit={handleTransactionSubmit}
    />
{/if}

<style>
    /* Verberg scrollbar maar behoud functionaliteit */
    .no-scrollbar {
        -ms-overflow-style: none;
        scrollbar-width: none;
    }
    .no-scrollbar::-webkit-scrollbar {
        display: none;
    }

    .animate-pop {
        animation: pop 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
    }

    @keyframes pop {
        0% {
            transform: scale(1);
        }
        50% {
            transform: scale(1.1);
        }
        100% {
            transform: scale(1);
        }
    }

    .text-accent {
        transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
    }

    /* Verwijder de hover animatie */
    .text-accent:hover {
        transform: scale(1);
    }

    .price-animate {
        animation: price-pop 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    }

    @keyframes price-pop {
        0% { transform: scale(1); }
        50% { transform: scale(1.2); color: rgb(134, 239, 172); }
        100% { transform: scale(1); }
    }

    /* Verwijder de standaard pijltjes van number inputs */
    input[type="number"]::-webkit-inner-spin-button,
    input[type="number"]::-webkit-outer-spin-button {
        -webkit-appearance: none;
        margin: 0;
    }
    input[type="number"] {
        -moz-appearance: textfield;
    }
</style> 