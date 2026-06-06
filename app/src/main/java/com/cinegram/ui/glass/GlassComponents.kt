package com.cinegram.ui.glass

import android.os.Build
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cinegram.ui.theme.GlassBacking
import com.cinegram.ui.theme.GlassHighlight
import com.cinegram.ui.theme.TextPrimary
import com.cinegram.ui.theme.ElectricCyan

// Modifier implementing the native GPU shader blur and liquid glass specular highlights
fun Modifier.glassmorphic(
    cornerRadius: Dp = 16.dp,
    borderWidth: Dp = 1.dp,
    blurRadius: Float = 25f
): Modifier = this.then(
    Modifier
        .graphicsLayer {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                renderEffect = RenderEffect.createBlurEffect(
                    blurRadius,
                    blurRadius,
                    Shader.TileMode.CLAMP
                ).asComposeRenderEffect()
            }
        }
        .background(
            brush = Brush.verticalGradient(
                colors = listOf(
                    GlassHighlight,
                    GlassBacking
                )
            ),
            shape = RoundedCornerShape(cornerRadius)
        )
        .clip(RoundedCornerShape(cornerRadius))
        .drawBehind {
            val strokeWidth = borderWidth.toPx()
            val path = Path().apply {
                addRoundRect(
                    RoundRect(
                        left = strokeWidth / 2,
                        top = strokeWidth / 2,
                        right = size.width - strokeWidth / 2,
                        bottom = size.height - strokeWidth / 2,
                        cornerRadius = CornerRadius(cornerRadius.toPx())
                    )
                )
            }
            
            // Specular highlighting border (iOS top highlight reflection)
            drawPath(
                path = path,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.35f),
                        Color.White.copy(alpha = 0.05f),
                        Color.Transparent
                    )
                ),
                style = Stroke(width = strokeWidth)
            )

            // Specular shadow border (iOS bottom shadow refraction)
            drawPath(
                path = path,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.05f),
                        Color.Black.copy(alpha = 0.25f)
                    )
                ),
                style = Stroke(width = strokeWidth)
            )
        }
)

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 16.dp,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier.glassmorphic(cornerRadius = cornerRadius),
        contentAlignment = Alignment.Center
    ) {
        content()
    }
}

@Composable
fun GlassBottomBar(
    modifier: Modifier = Modifier,
    content: @Composable RowScope.() -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp)
            .glassmorphic(cornerRadius = 28.dp, blurRadius = 30f)
            .padding(vertical = 6.dp, horizontal = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
            content = content
        )
    }
}

@Composable
fun GlassSeekBar(
    position: Long,
    duration: Long,
    onValueChange: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val progress = if (duration > 0) position.toFloat() / duration else 0f
    
    Row(
        modifier = modifier
            .fillMaxWidth()
            .glassmorphic(cornerRadius = 12.dp, blurRadius = 15f)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = formatTime(position),
            color = TextPrimary,
            fontSize = 12.sp
        )
        
        Slider(
            value = progress,
            onValueChange = { onValueChange((it * duration).toLong()) },
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
            colors = SliderDefaults.colors(
                activeTrackColor = ElectricCyan,
                inactiveTrackColor = Color.White.copy(alpha = 0.2f),
                thumbColor = ElectricCyan
            )
        )
        
        Text(
            text = formatTime(duration),
            color = TextPrimary,
            fontSize = 12.sp
        )
    }
}

@Composable
fun GlassPlayerControls(
    isPlaying: Boolean,
    onPlayPauseToggle: () -> Unit,
    onRewind: () -> Unit,
    onFastForward: () -> Unit,
    title: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .glassmorphic(cornerRadius = 20.dp, blurRadius = 30f)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = title,
            color = TextPrimary,
            fontSize = 16.sp,
            modifier = Modifier.padding(bottom = 12.dp)
        )
        
        Row(
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onRewind) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Rewind 10s",
                    tint = TextPrimary,
                    modifier = Modifier.size(28.dp)
                )
            }
            
            IconButton(
                onClick = onPlayPauseToggle,
                modifier = Modifier
                    .size(56.dp)
                    .background(ElectricCyan, shape = RoundedCornerShape(28.dp))
            ) {
                Icon(
                    imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = if (isPlaying) "Pause" else "Play",
                    tint = Color.Black,
                    modifier = Modifier.size(32.dp)
                )
            }
            
            IconButton(onClick = onFastForward) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Forward 10s",
                    tint = TextPrimary,
                    modifier = Modifier.size(28.dp)
                )
            }
        }
    }
}

private fun formatTime(ms: Long): String {
    val totalSeconds = ms / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return String.format("%02d:%02d", minutes, seconds)
}
