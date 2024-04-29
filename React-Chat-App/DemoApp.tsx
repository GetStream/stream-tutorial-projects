import {
  Chat,
  Channel,
  ChannelHeader,
  Thread,
  Window,
  MessageList,
  MessageInput
} from "stream-chat-react"; // Importing components from stream-chat-react library
import { StreamChat } from "stream-chat"; // Importing StreamChat from stream-chat library

import "stream-chat-react/dist/css/index.css"; // Importing CSS for stream-chat-react

// Creating a new StreamChat client with a demo key
const chatClient = new StreamChat("qk4nn7rpcn75");

// Demo user token
const userToken =
  "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiY29vbC1za3ktOSJ9.mhikC6HPqPKoCP4aHHfuH9dFgPQ2Fth5QoRAfolJjC4";

// Setting the user for the chat client
chatClient.setUser(
  {
    id: "cool-sky-9",
    name: "Cool sky",
    image: "https://getstream.io/random_svg/?id=cool-sky-9&name=Cool+sky"
  },
  userToken
);

// Creating a channel for the chat client
const channel = chatClient.channel("messaging", "godevs", {
  image:
    "https://cdn.chrisshort.net/testing-certificate-chains-in-go/GOPHER_MIC_DROP.png",
  name: "Talk about Go"
});

// Defining the App component
const App = () => (
  <Chat client={chatClient} theme={"messaging light"}>
    <Channel channel={channel}>
      <Window>
        <ChannelHeader />
        <MessageList />
        <MessageInput />
      </Window>
      <Thread />
    </Channel>
  </Chat>
);

export default App; // Exporting the App component

