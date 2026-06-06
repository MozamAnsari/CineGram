package com.cinegram.ui.screens.player

import android.app.Activity
import android.net.Uri
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.cinegram.ui.glass.GlassCard
import com.cinegram.ui.glass.GlassPlayerControls
import com.cinegram.ui.glass.GlassSeekBar
import com.cinegram.ui.glass.glassmorphic
import com.cinegram.ui.theme.ElectricCyan
import com.cinegram.ui.theme.TextPrimary
import kotlinx.coroutines.delay
import java.io.File

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(
    filePath: String,
    mediaId: String,
    viewModel: PlayerViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(filePath) {
        viewModel.loadInitialProgress(filePath)
    }

    if (!state.isLoaded) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = ElectricCyan)
        }
    } else {
        PlayerContent(
            filePath = filePath,
            mediaId = mediaId,
            initialPosition = state.initialPosition,
            viewModel = viewModel,
            onNavigateBack = onNavigateBack,
            modifier = modifier
        )
    }
}

@OptIn(UnstableApi::class)
@Composable
fun PlayerContent(
    filePath: String,
    mediaId: String,
    initialPosition: Long,
    viewModel: PlayerViewModel,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    
    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            val mediaItem = MediaItem.fromUri(Uri.fromFile(File(filePath)))
            setMediaItem(mediaItem)
            prepare()
            seekTo(initialPosition)
            playWhenReady = true
        }
    }

    var isPlaying by remember { mutableStateOf(true) }
    var currentPosition by remember { mutableStateOf(initialPosition) }
    var duration by remember { mutableStateOf(0L) }
    var playbackSpeed by remember { mutableStateOf(1.0f) }
    
    var showControls by remember { mutableStateOf(true) }
    var gestureHudText by remember { mutableStateOf<String?>(null) }
    
    DisposableEffect(exoPlayer) {
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) {
                    duration = exoPlayer.duration
                }
            }

            override fun onIsPlayingChanged(playing: Boolean) {
                isPlaying = playing
            }
        }
        exoPlayer.addListener(listener)
        onDispose {
            viewModel.saveProgress(mediaId, filePath, exoPlayer.currentPosition, exoPlayer.duration)
            exoPlayer.removeListener(listener)
            exoPlayer.release()
        }
    }

    LaunchedEffect(exoPlayer) {
        while (true) {
            delay(5000)
            if (exoPlayer.isPlaying) {
                currentPosition = exoPlayer.currentPosition
                viewModel.saveProgress(mediaId, filePath, currentPosition, exoPlayer.duration)
            }
        }
    }

    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            while (true) {
                currentPosition = exoPlayer.currentPosition
                delay(200)
            }
        }
    }

    LaunchedEffect(showControls) {
        if (showControls) {
            delay(3500)
            showControls = false
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = {
                        showControls = !showControls
                    },
                    onDoubleTap = { offset ->
                        val screenWidth = size.width
                        if (offset.x < screenWidth / 2) {
                            val newPos = (exoPlayer.currentPosition - 10000).coerceAtLeast(0)
                            exoPlayer.seekTo(newPos)
                            currentPosition = newPos
                            gestureHudText = "Rewind 10s"
                        } else {
                            val newPos = (exoPlayer.currentPosition + 10000).coerceAtMost(exoPlayer.duration)
                            exoPlayer.seekTo(newPos)
                            currentPosition = newPos
                            gestureHudText = "Forward 10s"
                        }
                    }
                )
            }
    ) {
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = false
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        LaunchedEffect(gestureHudText) {
            if (gestureHudText != null) {
                delay(1200)
                gestureHudText = null
            }
        }
        
        AnimatedVisibility(
            visible = gestureHudText != null,
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            gestureHudText?.let { text ->
                Box(
                    modifier = Modifier
                        .glassmorphic(cornerRadius = 16.dp, blurRadius = 15f)
                        .padding(horizontal = 24.dp, vertical = 12.dp)
                ) {
                    Text(
                        text = text,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                }
            }
        }

        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn() + slideInVertically(initialOffsetY = { -it }),
            exit = fadeOut() + slideOutVertically(initialOffsetY = { -it }),
            modifier = Modifier.fillMaxSize()
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Black.copy(alpha = 0.6f), Color.Transparent)
                            )
                        )
                        .padding(horizontal = 16.dp, vertical = 24.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                    
                    Spacer(modifier = Modifier.width(16.dp))
                    
                    Text(
                        text = File(filePath).name,
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1
                    )

                    Spacer(modifier = Modifier.weight(1f))

                    var showSpeedDialog by remember { mutableStateOf(false) }
                    TextButton(
                        onClick = { showSpeedDialog = true },
                        modifier = Modifier
                            .glassmorphic(cornerRadius = 8.dp, blurRadius = 10f)
                            .padding(horizontal = 8.dp)
                    ) {
                        Text(
                            text = "${playbackSpeed}x",
                            color = ElectricCyan,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    if (showSpeedDialog) {
                        AlertDialog(
                            onDismissRequest = { showSpeedDialog = false },
                            confirmButton = {},
                            title = { Text("Playback Speed", color = TextPrimary) },
                            text = {
                                Column {
                                    listOf(0.5f, 1.0f, 1.25f, 1.5f, 2.0f).forEach { speed ->
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clickable {
                                                    playbackSpeed = speed
                                                    exoPlayer.setPlaybackSpeed(speed)
                                                    showSpeedDialog = false
                                                }
                                                .padding(vertical = 12.dp),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text(
                                                text = "${speed}x",
                                                color = if (playbackSpeed == speed) ElectricCyan else TextPrimary,
                                                fontWeight = if (playbackSpeed == speed) FontWeight.Bold else FontWeight.Normal
                                            )
                                        }
                                    }
                                }
                            },
                            containerColor = Color(0xFF161820)
                        )
                    }
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.6f))
                            )
                        )
                        .padding(16.dp)
                ) {
                    GlassSeekBar(
                        position = currentPosition,
                        duration = duration,
                        onValueChange = { newPos ->
                            exoPlayer.seekTo(newPos)
                            currentPosition = newPos
                        }
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))

                    GlassPlayerControls(
                        isPlaying = isPlaying,
                        onPlayPauseToggle = {
                            if (exoPlayer.isPlaying) {
                                exoPlayer.pause()
                            } else {
                                exoPlayer.play()
                            }
                        },
                        onRewind = {
                            val newPos = (exoPlayer.currentPosition - 10000).coerceAtLeast(0)
                            exoPlayer.seekTo(newPos)
                            currentPosition = newPos
                        },
                        onFastForward = {
                            val newPos = (exoPlayer.currentPosition + 10000).coerceAtMost(exoPlayer.duration)
                            exoPlayer.seekTo(newPos)
                            currentPosition = newPos
                        },
                        title = "Double tap left/right to seek 10s",
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }
            }
        }
    }
}
