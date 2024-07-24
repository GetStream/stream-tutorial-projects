import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { SealdContextProvider } from './contexts/SealdContext.tsx';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <SealdContextProvider>
      <App />
    </SealdContextProvider>
  </React.StrictMode>
);
