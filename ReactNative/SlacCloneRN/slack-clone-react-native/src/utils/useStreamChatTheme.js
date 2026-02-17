import {useTheme} from '@react-navigation/native';

const useStreamChatTheme = () => {
  const {colors, dark} = useTheme();

  return {
    messageSimple: {
      content: {
        containerInner: {
          backgroundColor: 'transparent',
          borderWidth: 0,
        },
        textContainer: {
          backgroundColor: 'transparent',
          borderWidth: 0,
        },
      },
    },
    messageList: {
      container: {
        backgroundColor: colors.background,
      },
    },
    messageInput: {
      container: {
        backgroundColor: colors.background,
        borderTopColor: '#979A9A',
        borderTopWidth: 0.4,
      },
      inputBox: {
        fontSize: 15,
        color: colors.text,
      },
    },
    thread: {
      newThread: {
        display: 'none',
      },
    },
  };
};

export default useStreamChatTheme;
