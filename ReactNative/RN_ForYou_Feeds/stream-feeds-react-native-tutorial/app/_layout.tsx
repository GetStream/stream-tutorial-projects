import {
  DarkTheme,
  DefaultTheme,
  ThemeProvider,
} from "@react-navigation/native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import "react-native-reanimated";
import { useColorScheme } from "@/hooks/use-color-scheme";
import {
  StreamFeeds,
  useCreateFeedsClient,
} from "@stream-io/feeds-react-native-sdk";
import { API_KEY, CURRENT_USER } from "@/user";
import { OwnFeedsContextProvider } from "@/contexts/own-feeds-context";

export const unstable_settings = {
  anchor: "(tabs)",
};

export default function RootLayout() {
  const colorScheme = useColorScheme();

  const client = useCreateFeedsClient({
    apiKey: API_KEY,
    tokenOrProvider: CURRENT_USER.token,
    userData: {
      id: CURRENT_USER.id,
      name: CURRENT_USER.name,
    },
  });

  if (!client) {
    return null;
  }

  return (
    <StreamFeeds client={client}>
      <OwnFeedsContextProvider>
        <ThemeProvider
          value={colorScheme === "dark" ? DarkTheme : DefaultTheme}
        >
          <Stack>
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            <Stack.Screen
              name="comments-modal"
              options={{ presentation: "modal", title: "Comments" }}
            />
          </Stack>
          <StatusBar style="auto" />
        </ThemeProvider>
      </OwnFeedsContextProvider>
    </StreamFeeds>
  );
}
