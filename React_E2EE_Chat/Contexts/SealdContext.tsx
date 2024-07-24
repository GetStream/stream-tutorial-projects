import React, { useCallback } from 'react';
import { createContext, useContext, useState } from 'react';
import SealdSDK from '@seald-io/sdk'; // if your bundler supports the "browser" field in package.json (supported by Webpack 5)
import SealdSDKPluginSSKSPassword from '@seald-io/sdk-plugin-ssks-password';
import { EncryptionSession } from '@seald-io/sdk/lib/main.js';
import { Message, SendMessageOptions, StreamChat } from 'stream-chat';
import { DefaultStreamChatGenerics } from 'stream-chat-react';
import { registerUser } from './registerUser';

type SealdState = {
  sealdClient: typeof SealdSDK | undefined;
  encryptionSession: EncryptionSession | undefined;
  sealdId: string | undefined;
  loadingState: 'loading' | 'finished';
  initializeSeald: (userId: string, password: string) => void;
  encryptMessage: (
    message: string,
    channelId: string,
    chatClient: StreamChat,
    customMessageData: Partial<Message<DefaultStreamChatGenerics>> | undefined,
    options: SendMessageOptions | undefined
  ) => Promise<void>;
  decryptMessage: (message: string, sessionId: string) => Promise<string>;
};

const initialValue: SealdState = {
  sealdClient: undefined,
  encryptionSession: undefined,
  sealdId: undefined,
  loadingState: 'loading',
  initializeSeald: async () => {},
  encryptMessage: async () => {},
  decryptMessage: async () => '',
};

const SealdContext = createContext<SealdState>(initialValue);

export const SealdContextProvider = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  const [myState, setMyState] = useState<SealdState>(initialValue);

  const initializeSeald = useCallback(
    async (userId: string, password: string) => {
      console.log('Initializing Seald');
      const appId = import.meta.env.VITE_SEALD_APP_ID;
      const apiURL = import.meta.env.VITE_API_URL;
      const storageURL = import.meta.env.KEY_STORAGE_URL;

      const seald = SealdSDK({
        appId,
        apiURL,
        plugins: [SealdSDKPluginSSKSPassword(storageURL)],
      });

      // ⚠️ IMPORTANT:
      // This is a one-time operation, to create the user's identity
      // It is already done for the current user, so we only need to
      // comment this in if there's a different user
      // registerUser();

      const identity = await seald.ssksPassword.retrieveIdentity({
        userId,
        password,
      });

      const session: EncryptionSession = await seald.createEncryptionSession({
        sealdIds: [identity.sealdId],
      });

      setMyState((myState) => {
        return {
          ...myState,
          sealdClient: seald,
          encryptionSession: session,
          sealdId: identity.sealdId,
          loadingState: 'finished',
        };
      });
    },
    []
  );

  const encryptMessage = useCallback(
    async (
      message: string,
      channelId: string,
      chatClient: StreamChat,
      customMessageData:
        | Partial<Message<DefaultStreamChatGenerics>>
        | undefined,
      options: SendMessageOptions | undefined
    ) => {
      let messageToSend = message;
      if ((myState.sealdId, myState.encryptionSession)) {
        console.log('Starting message encryption');
        const encryptedMessage = await myState.encryptionSession.encryptMessage(
          message
        );

        console.log('encryptedMessage', encryptedMessage);
        messageToSend = encryptedMessage;
      }
      try {
        const channel = chatClient.channel('messaging', channelId);
        const sendResult = await channel.sendMessage({
          text: messageToSend,
          customMessageData,
          options,
        });

        console.log('sendResult', sendResult);
      } catch (error) {
        console.log('error', error);
      }
    },
    [myState.sealdId, myState.encryptionSession]
  );

  const decryptMessage = useCallback(
    async (message: string, sessionId: string) => {
      let encryptionSession = myState.encryptionSession;
      if (!encryptionSession || encryptionSession.sessionId !== sessionId) {
        // Either there is no session, or it doesn't match with the session id
        console.log('No session found for decryption or session id mismatch');
        encryptionSession = await myState.sealdClient.retrieveEncryptionSession(
          {
            sessionId,
          }
        );
        console.log('encryptionSession: ', encryptionSession);
        setMyState((myState) => {
          return {
            ...myState,
            encryptionSession: encryptionSession,
          };
        });
      }

      console.log('Starting message decryption: ', message);
      const decryptedMessage =
        (await encryptionSession?.decryptMessage(message)) || message;
      console.log('Decrypted message: ', decryptedMessage);

      return decryptedMessage;
    },
    [myState.encryptionSession, myState.sealdClient]
  );

  const store: SealdState = {
    sealdClient: myState.sealdClient,
    encryptionSession: myState.encryptionSession,
    sealdId: myState.sealdId,
    loadingState: myState.loadingState,
    initializeSeald,
    encryptMessage,
    decryptMessage,
  };

  return (
    <SealdContext.Provider value={store}>{children}</SealdContext.Provider>
  );
};

export const useSealdContext = () => useContext(SealdContext);
