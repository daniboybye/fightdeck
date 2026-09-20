package com.fightdeck.swiftcore.ui

import android.app.PictureInPictureParams
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.util.Rational
import android.widget.MediaController
import android.widget.VideoView
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.compose.composable
import com.fightdeck.fightevents.FightEventsJava
import com.fightdeck.swiftcore.data.MediaItem
import com.fightdeck.swiftcore.design.Tokens
import java.math.BigDecimal
import kotlinx.coroutines.delay

/** How often playback position is sampled, so the floating window can pick the clip back up. */
private const val POSITION_SAMPLE_MS = 500L

@Composable
internal fun VideoScreen(
    item: MediaItem,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    var playbackError by remember(item.id) { mutableStateOf<String?>(null) }
    // Not composition state: the replacement surface is composed before the old one is released,
    // so a snapshot value would still read zero and the clip would start over.
    val resumeAt = remember(item.id) { intArrayOf(0) }
    offerFloatingWindow(autoEnter = playbackError == null)

    if (isInFloatingWindow()) {
        // The window is the size of the picture, so the picture is all it shows.
        VideoSurface(
            item = item,
            resumeAt = resumeAt,
            showControls = false,
            onError = { playbackError = it },
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
        )
        return
    }

    DetailScaffold(title = "Video", onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            item {
                val error = playbackError
                if (error != null) {
                    Text(error, color = Tokens.negative)
                } else {
                    VideoSurface(
                        item = item,
                        resumeAt = resumeAt,
                        showControls = true,
                        onError = { playbackError = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(16f / 9f)
                            .clip(RoundedCornerShape(Tokens.radiusMd)),
                    )
                }
            }
            item { Text(item.title, style = MaterialTheme.typography.titleLarge) }
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = RoundedCornerShape(Tokens.radiusLg),
                ) {
                    Column(Modifier.padding(Tokens.spacingLg)) {
                        DetailRow("Duration", item.durationLabel)
                        HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                        DetailRow("Format", item.kind.uppercase())
                    }
                }
            }
            item.note?.let { note ->
                item {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(
                            Icons.Default.Info,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(Tokens.spacingSm))
                        Text(
                            note,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

/**
 * VideoView owns its MediaPlayer and drops it when the surface goes away, so moving between this
 * screen and the floating window starts the clip again — from where it left off.
 */
@Composable
private fun VideoSurface(
    item: MediaItem,
    resumeAt: IntArray,
    showControls: Boolean,
    onError: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var player by remember { mutableStateOf<VideoView?>(null) }

    // The replacement surface is built before this one is torn down, so reading the position on
    // the way out is too late for it to be of any use. Sampling while the clip plays is not.
    LaunchedEffect(player) {
        val view = player ?: return@LaunchedEffect
        while (true) {
            delay(POSITION_SAMPLE_MS)
            if (view.isPlaying) resumeAt[0] = view.currentPosition
        }
    }

    AndroidView(
        factory = { context ->
            VideoView(context).apply {
                player = this
                setVideoURI(Uri.parse(item.url))
                if (showControls) {
                    setMediaController(
                        MediaController(context).also { controller ->
                            controller.setAnchorView(this)
                        },
                    )
                }
                setOnPreparedListener { mediaPlayer ->
                    mediaPlayer.setVolume(1f, 1f)
                    // VideoView.seekTo lands on the nearest keyframe, which on these clips is up
                    // to ten seconds back; the clip should carry on where it was, not before.
                    mediaPlayer.seekTo(resumeAt[0].toLong(), MediaPlayer.SEEK_CLOSEST)
                    start()
                }
                setOnErrorListener { _, what, extra ->
                    post { onError("Cannot start playback ($what/$extra)") }
                    true
                }
            }
        },
        modifier = modifier,
        onRelease = { view -> view.stopPlayback() },
    )
}

/**
 * Offers the system a floating window for when the app is minimised. Leaving the screen that
 * made the offer takes it back, so only video minimises this way.
 */
@Composable
private fun offerFloatingWindow(autoEnter: Boolean) {
    val activity = LocalActivity.current ?: return

    LaunchedEffect(activity, autoEnter) {
        activity.setPictureInPictureParams(floatingWindowParams(autoEnter))
    }
    DisposableEffect(activity) {
        onDispose { activity.setPictureInPictureParams(floatingWindowParams(autoEnter = false)) }
    }
}

/** Whether the app is in that floating window right now. */
@Composable
internal fun isInFloatingWindow(): Boolean {
    val activity = LocalActivity.current ?: return false
    // Moving into the window resizes it, and a resize is a configuration change, which is what
    // brings this composable back here to ask again.
    val configuration = LocalConfiguration.current
    return remember(configuration) { activity.isInPictureInPictureMode }
}

private fun floatingWindowParams(autoEnter: Boolean): PictureInPictureParams {
    val params = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
    // Letting the system enter the window itself, rather than asking from onUserLeaveHint, is
    // what makes the swipe-to-home gesture animate into it. Android 12 and newer only.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        params.setAutoEnterEnabled(autoEnter)
    }
    return params.build()
}

internal val MediaItem.durationLabel: String
    get() = FightEventsJava.formatDuration(durationSeconds.toLong())
