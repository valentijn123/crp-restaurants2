import PaymentConfirmation from '../components/PaymentConfirmation.svelte';

export const actions = [
    {
        id: 'open-payment-confirmation',
        label: 'Open Betaling Bevestiging (Klant)',
        category: 'UI',
        action: () => {
            const modal = new PaymentConfirmation({
                target: document.body,
                props: {
                    total: 25.99,
                    businessName: "McDonalds",
                    paymentMethod: 'bank',
                    sourcePlayer: '1'
                }
            });

            // Cleanup wanneer nodig
            modal.$on('close', () => {
                modal.$destroy();
            });

            modal.$on('confirm', () => {
                console.log('Betaling bevestigd door klant');
                modal.$destroy();
            });

            modal.$on('decline', () => {
                console.log('Betaling geweigerd door klant');
                modal.$destroy();
            });
        }
    }
]; 