package com.cinegram.ui.screens.detail

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.rememberAsyncImagePainter
import com.cinegram.domain.model.MediaFile
import com.cinegram.ui.glass.GlassCard
import com.cinegram.ui.glass.glassmorphic
import com.cinegram.ui.theme.DarkBackground
import com.cinegram.ui.theme.ElectricCyan
import com.cinegram.ui.theme.TextPrimary
import com.cinegram.ui.theme.TextSecondary

@Composable
fun DetailScreen(
    mediaId: String,
    viewModel: DetailViewModel,
    onNavigateBack: () -> Unit,
    onPlayFile: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.state.collectAsState()
    val scrollState = rememberScrollState()

    LaunchedEffect(mediaId) {
        viewModel.loadMediaItem(mediaId)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        val item = state.mediaItem
        
        if (state.isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
                color = ElectricCyan
            )
        } else if (state.error != null) {
            Text(
                text = state.error ?: "Error loading details",
                color = Color.Red,
                modifier = Modifier.align(Alignment.Center)
            )
        } else if (item != null) {
            if (item.backdropPath != null) {
                Image(
                    painter = rememberAsyncImagePainter(model = item.backdropPath),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp)
                )
            }
            
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.Transparent, DarkBackground),
                            startY = 100f
                        )
                    )
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 16.dp)
            ) {
                Spacer(modifier = Modifier.height(200.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Bottom
                ) {
                    Card(
                        modifier = Modifier
                            .width(110.dp)
                            .height(165.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        if (item.posterPath != null) {
                            Image(
                                painter = rememberAsyncImagePainter(model = item.posterPath),
                                contentDescription = null,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                        } else {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(Color.White.copy(alpha = 0.05f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = item.title,
                                    color = TextPrimary,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.padding(4.dp)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.width(16.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = item.title,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            if (item.releaseDate != null) {
                                Text(
                                    text = item.releaseDate.take(4),
                                    fontSize = 14.sp,
                                    color = TextSecondary
                                )
                            }
                            if (item.voteAverage != null) {
                                Text(
                                    text = "★ ${String.format("%.1f", item.voteAverage)}",
                                    fontSize = 14.sp,
                                    color = ElectricCyan,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                if (!item.overview.isNullOrBlank()) {
                    Text(
                        text = "Overview",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary,
                        modifier = Modifier.padding(vertical = 8.dp)
                    )
                    Text(
                        text = item.overview,
                        fontSize = 14.sp,
                        lineHeight = 22.sp,
                        color = TextSecondary
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = "Playable Files",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    modifier = Modifier.padding(vertical = 8.dp)
                )

                if (item.mediaFiles.isEmpty()) {
                    Text(text = "No local files found.", color = TextSecondary)
                } else {
                    item.mediaFiles.forEach { file ->
                        FilePlayRow(file = file, onClick = { onPlayFile(file.path) })
                    }
                }
                
                Spacer(modifier = Modifier.height(100.dp))
            }
        }

        Box(
            modifier = Modifier
                .padding(16.dp)
                .align(Alignment.TopStart)
                .size(44.dp)
                .glassmorphic(cornerRadius = 22.dp, blurRadius = 15f)
                .clickable(onClick = onNavigateBack),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = TextPrimary,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
fun FilePlayRow(file: MediaFile, onClick: () -> Unit) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = "Play",
                tint = ElectricCyan,
                modifier = Modifier.size(28.dp)
            )
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = file.name,
                    color = TextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                
                Spacer(modifier = Modifier.height(4.dp))
                
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = formatFileSize(file.size),
                        fontSize = 12.sp,
                        color = TextSecondary
                    )
                    Text(
                        text = formatDuration(file.duration),
                        fontSize = 12.sp,
                        color = TextSecondary
                    )
                    if (file.resolution != null) {
                        Text(
                            text = file.resolution,
                            fontSize = 12.sp,
                            color = TextSecondary
                        )
                    }
                }
            }
        }
    }
}

private fun formatFileSize(size: Long): String {
    if (size <= 0) return "0 B"
    val units = arrayOf("B", "KB", "MB", "GB", "TB")
    val digitGroups = (Math.log10(size.toDouble()) / Math.log10(1024.0)).toInt()
    return String.format("%.2f %s", size / Math.pow(1024.0, digitGroups.toDouble()), units[digitGroups])
}

private fun formatDuration(durationMs: Long): String {
    val totalSeconds = durationMs / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    return if (hours > 0) {
        String.format("%dh %02dm", hours, minutes)
    } else {
        String.format("%dm", minutes)
    }
}
