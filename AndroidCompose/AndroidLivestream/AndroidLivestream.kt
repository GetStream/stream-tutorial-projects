package com.example.livestream

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import io.getstream.video.android.compose.permission.LaunchCallPermissions
import io.getstream.video.android.compose.theme.VideoTheme
import io.getstream.video.android.compose.ui.components.video.VideoRenderer
import io.getstream.video.android.core.GEO
import io.getstream.video.android.core.RealtimeConnection
import io.getstream.video.android.core.StreamVideoBuilder
import io.getstream.video.android.model.User
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        /**
         1. Define properties
         2. Create a user
         3. Create the video client
         4. Create and join a call
         5. Display text on the screen
         */

        // 1. Define properties
        val userToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiTmF0YXNpX0RhYWxhIiwiaXNzIjoicHJvbnRvIiwic3ViIjoidXNlci9OYXRhc2lfRGFhbGEiLCJpYXQiOjE2OTk5NDk0MTAsImV4cCI6MTcwMDU1NDIxNX0.apWErDQw2MWfOprZkdw9jI0ndejlZiRDDyxsy8Xn93U"
        val userId = "Natasi_Daala"
        val callId = "HlpP7dATGeTn"

        // 2. Create a user
        val user = User(
            id = userId, // any string
            name = "Tutorial" // name and image are used in the UI
        )

        // 3. Create the video client. For a production app we recommend adding the client to your Application class or di module.
        val client = StreamVideoBuilder(
            context = applicationContext,
            apiKey = "hd8szvscpxvd", // demo API key
            geo = GEO.GlobalEdgeNetwork,
            user = user,
            token = userToken,
        ).build()

        // 4.Create and join a call
        val call = client.call("livestream", callId)
        lifecycleScope.launch {
            // join the call
            val result = call.join(create = true)
            result.onError {
                Toast.makeText(applicationContext, "uh oh $it", Toast.LENGTH_SHORT).show()
            }
        }

        setContent {
            // request the Android runtime permissions for the camera and microphone
            LaunchCallPermissions(call = call)

            VideoTheme {
                // 1. Call and participant state
                val connection by call.state.connection.collectAsState()
                val totalParticipants by call.state.totalParticipants.collectAsState()
                val backstage by call.state.backstage.collectAsState()
                val localParticipant by call.state.localParticipant.collectAsState()
                val video = localParticipant?.video?.collectAsState()?.value
                val duration by call.state.duration.collectAsState()

                Scaffold(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(VideoTheme.colors.appBackground)
                        .padding(6.dp),
                    contentColor = VideoTheme.colors.appBackground,
                    backgroundColor = VideoTheme.colors.appBackground,
                    topBar = {
                        if (connection == RealtimeConnection.Connected) {
                            if (!backstage) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(6.dp)
                                ) {
                                    var total = ""
                                    Text(
                                        modifier = Modifier
                                            .align(Alignment.CenterEnd)
                                            .background(
                                                color = VideoTheme.colors.primaryAccent,
                                                shape = RoundedCornerShape(6.dp)
                                            )
                                            .padding(horizontal = 12.dp, vertical = 4.dp),
                                        text = "Live $total",
                                        color = Color.White
                                    )

                                    Text(
                                        modifier = Modifier.align(Alignment.Center),
                                        text = "Live for $duration",
                                        color = VideoTheme.colors.textHighEmphasis
                                    )
                                }
                            }
                        }
                    },
                    bottomBar = {
                        Button(
                            colors = ButtonDefaults.buttonColors(
                                contentColor = VideoTheme.colors.primaryAccent,
                                backgroundColor = VideoTheme.colors.primaryAccent
                            ),
                            onClick = {
                                val rtmp = call.state.ingress.value
                                Log.i("Tutorial", "RTMP url and streamingKey: $rtmp")
                                lifecycleScope.launch {
                                    if (backstage) call.goLive() else call.stopLive()
                                }
                            }
                        ) {
                            Text(
                                text = if (backstage) "Go Live" else "Stop Broadcast",
                                color = Color.White
                            )
                        }
                    }
                ) {
                    VideoRenderer(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(it)
                            .clip(RoundedCornerShape(6.dp)),
                        call = call,
                        video = video,
                        videoFallbackContent = {
                            Text(text = "Video rendering failed")
                        }
                    )
                }
            }
        }
    }
}

// Display the text at the center of the screen
@Composable
fun CenteredText(text: String) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = text)
    }
}

