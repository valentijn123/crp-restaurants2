import { DebugItem } from '@typings/events'
import { toggleVisible } from './visibility'
import { Send } from '@enums/events'
import { DebugEventSend, SendEvent } from '@utils/eventsHandlers'
import PaymentConfirmation from '../../components/PaymentConfirmation.svelte'
import OrderReceiver from '../../components/OrderReceiver.svelte'
import OrderNotification from '../../components/OrderNotification.svelte'
import { Receive } from '@enums/events'

/**
 * The debug actions that will show up in the debug menu.
 */
const SendDebuggers: DebugItem[] = [
    {
        label: 'Visibility',
        actions: [
            {
                label: 'True',
                action: () => toggleVisible(true),
            },
            {
                label: 'False',
                action: () => toggleVisible(false),
            },
        ],
    },
    {
        label: 'Slider',
        actions: [
            {
                label: 'Change Value',
                action: (value: number) =>
                    DebugEventSend(Send.imageResize, value),
                value: 50,
                type: 'slider',
            },
        ],
    },
    {
        label: 'Checkbox',
        actions: [
            {
                label: 'Toggle',
                action: (value: number) =>
                    DebugEventSend(Send.imageInvert, value),
                value: false,
                type: 'checkbox',
            },
        ],
    },
    {
        label: 'Text',
        actions: [
            {
                label: 'Type',
                action: (value: string) =>
                    DebugEventSend(Send.changeText, value),
                type: 'text',
                placeholder: 'Type here',
            },
        ],
    },
    {
        label: 'Button',
        actions: [
            {
                label: 'Reset Text',
                action: () => DebugEventSend(Send.resetText),
            },
        ],
    },

    {
        label: 'Debug receiver example.',
        actions: [
            {
                label: 'Emulates a POST To Client and get back a response.',
                type: 'text',
                placeholder: 'Type text to reverse.',
                action: (value: string) => SendEvent("debug", value).then((reversed: string) => console.log(reversed,'color: red', 'color: white', 'color: green')),
            },
        ],
    },
    {
        label: 'UI Debug',
        actions: [
            {
                label: 'Open Betaling Bevestiging (Klant)',
                action: async () => {
                    const paymentMethod = 'bank';
                    
                    // Haal het huidige saldo op van de server via de NUI callback
                    const currentBalance = await SendEvent('getMoney', { 
                        moneyType: paymentMethod 
                    });

                    console.log('Ontvangen saldo:', currentBalance);

                    const modal = new PaymentConfirmation({
                        target: document.body,
                        props: {
                            total: 25.99,
                            businessName: 'McDonalds',
                            paymentMethod,
                            currentBalance: currentBalance || 0
                        }
                    });

                    modal.$on('close', () => modal.$destroy());
                    modal.$on('confirm', () => {
                        console.log('Betaling bevestigd door klant');
                        modal.$destroy();
                    });
                    modal.$on('decline', () => {
                        console.log('Betaling geweigerd door klant');
                        modal.$destroy();
                    });
                }
            },
            {
                id: 'toggle-order-receiver',
                label: 'Toggle Bestellingen Ontvanger',
                action: () => {
                    const existingReceiver = document.querySelector('#order-receiver');
                    if (existingReceiver) {
                        existingReceiver.remove();
                    } else {
                        new OrderReceiver({
                            target: document.body,
                            props: {}
                        });
                    }
                }
            },
            {
                id: 'toggle-order-notifications',
                label: 'Toggle Bestellingen Notificaties',
                action: () => {
                    const existing = document.querySelector('#order-notifications');
                    
                    // Als er nog geen notifications component is, maak deze aan
                    if (!existing) {
                        new OrderNotification({
                            target: document.body,
                            props: {}
                        });
                    }
                    
                    // Stuur een test order via een custom event
                    const testOrder = {
                        id: crypto.randomUUID(),
                        items: [
                            { product: { id: 1, name: 'Big Mac', price: 5.99 }, quantity: 2 },
                            { product: { id: 2, name: 'Cola', price: 2.49 }, quantity: 1 }
                        ],
                        total: 14.47,
                        timestamp: new Date().toISOString(),
                        playerId: '1',
                        paymentMethod: 'bank'
                    };

                    const event = new CustomEvent(Receive.newOrder, { 
                        detail: testOrder 
                    });
                    window.dispatchEvent(event);
                }
            },
            {
                id: 'open-cash-register',
                label: 'Open Kassa',
                action: () => {
                    // Simuleer een register met test data
                    const testRegister = {
                        id: "test_register",
                        business: "burgershot",
                        categories: [
                            { id: 'all', name: 'Alles' },
                            { id: 'burgers', name: 'Burgers' },
                            { id: 'drinks', name: 'Dranken' }
                        ],
                        products: [
                            {
                                id: "burger_bleeder",
                                name: "Bleeder",
                                price: 5.99,
                                category: "burgers",
                                image: "nui://ox_inventory/web/images/burger_bleeder.png"
                            },
                            {
                                id: "drink_cola",
                                name: "eCola",
                                price: 2.49,
                                category: "drinks",
                                image: "nui://ox_inventory/web/images/drink_cola.png"
                            }
                        ]
                    };

                    // Dispatch het NUI message
                    window.dispatchEvent(new MessageEvent('message', {
                        data: {
                            action: 'resource:visible',
                            data: {
                                show: true,
                                business: testRegister.business,
                                categories: testRegister.categories,
                                products: testRegister.products
                            }
                        }
                    }));
                }
            }
        ]
    }
]

export default SendDebuggers
