<script lang="ts">
    import { CONFIG, IS_BROWSER } from './stores/stores';
    import { InitialiseListen } from '@utils/listeners';
    import Visibility from '@providers/Visibility.svelte';
    import CashRegister from '@components/CashRegister.svelte';
    import { onMount } from 'svelte';
    import OrderNotification from '@components/OrderNotification.svelte';
    import OrderReceiver from './components/OrderReceiver.svelte';

    CONFIG.set({
        fallbackResourceName: 'debug',
        allowEscapeKey: true,
    });

    InitialiseListen();

    onMount(() => {
        console.log('[DEBUG] Mounting OrderNotification component');
        const notification = new OrderNotification({
            target: document.body,
            props: {}
        });
        
        const receiver = new OrderReceiver({
            target: document.body,
            props: {}
        });
        
        return () => {
            console.log('[DEBUG] Cleaning up components');
            notification.$destroy();
            receiver.$destroy();
        };
    });
</script>

<Visibility>
    <CashRegister />
</Visibility>

{#if import.meta.env.DEV}
    {#if $IS_BROWSER}
        {#await import('./providers/Debug.svelte') then { default: Debug }}
            <Debug />
        {/await}
    {/if}
{/if}
