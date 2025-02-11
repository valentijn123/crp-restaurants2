import './app.css'
import App from './App.svelte';
import { initializePaymentHandler } from './utils/paymentHandler';

const app = new App({
    target: document.getElementById('app') as HTMLElement
});

// Initialize the payment handler
initializePaymentHandler();

export default app;
