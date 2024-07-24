import { useEffect, useState } from 'react';
import { useMessageContext } from 'stream-chat-react';
import { useSealdContext } from './contexts/SealdContext';

export default function EncryptedMessage(): JSX.Element {
  const { message } = useMessageContext();
  const { decryptMessage } = useSealdContext();
  const [displayedMessage, setDisplayedMessage] = useState<string | undefined>(
    message.text
  );

  useEffect(() => {
    if (message.text) {
      const sessionId = JSON.parse(message.text).sessionId;
      decryptMessage(message.text, sessionId).then(
        (decryptedMessage: string) => {
          setDisplayedMessage(decryptedMessage);
        }
      );
    }
  }, [message, decryptMessage]);
  return (
    <div className='messageBubble'>
      <p>{displayedMessage}</p>
    </div>
  );
}
