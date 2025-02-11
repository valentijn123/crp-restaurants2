import PaymentConfirmation from '../components/PaymentConfirmation.svelte';
import { SendEvent } from './eventsHandlers';

export function initializePaymentHandler() {
    window.addEventListener('message', (event) => {
        if (event.data?.action === 'resource:showPaymentConfirmation') {
            console.log('[DEBUG] Betalingsbevestiging modal aanmaken');
            const paymentData = event.data.data;
            
            try {
                const modal = new PaymentConfirmation({
                    target: document.body,
                    props: {
                        total: paymentData.total,
                        businessName: paymentData.businessName,
                        paymentMethod: paymentData.paymentMethod,
                        sourcePlayer: paymentData.sourcePlayer,
                        cart: paymentData.items || [],
                        mounted: true
                    }
                });

                console.log('[DEBUG] Betalingsbevestiging modal aangemaakt:', modal);

                modal.$on('confirm', () => {
                    console.log('[DEBUG] Betaling bevestigd');
                    SendEvent('confirmPayment', {
                        sourcePlayer: paymentData.sourcePlayer,
                        accepted: true,
                        businessName: paymentData.businessName,
                        total: paymentData.total,
                        paymentMethod: paymentData.paymentMethod,
                        items: paymentData.items || []
                    });
                    modal.$destroy();
                });

                modal.$on('decline', () => {
                    console.log('[DEBUG] Payment declined');
                    SendEvent('confirmPayment', {
                        sourcePlayer: paymentData.sourcePlayer,
                        accepted: false,
                        businessName: paymentData.businessName,
                        total: paymentData.total,
                        paymentMethod: paymentData.paymentMethod,
                        items: paymentData.items || []
                    });
                    modal.$destroy();
                });

                modal.$on('close', () => {
                    console.log('[DEBUG] Payment modal closed');
                    SendEvent('confirmPayment', {
                        sourcePlayer: paymentData.sourcePlayer,
                        accepted: false,
                        businessName: paymentData.businessName,
                        total: paymentData.total,
                        paymentMethod: paymentData.paymentMethod,
                        items: paymentData.items || []
                    });
                    modal.$destroy();
                });
            } catch (error) {
                console.error('[ERROR] Failed to create payment confirmation:', error);
            }
        }
    });
}
