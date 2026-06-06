package com.cinegram

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.cinegram.ui.glass.GlassBottomBar
import com.cinegram.ui.screens.detail.DetailScreen
import com.cinegram.ui.screens.detail.DetailViewModel
import com.cinegram.ui.screens.home.HomeScreen
import com.cinegram.ui.screens.home.HomeViewModel
import com.cinegram.ui.screens.library.LibraryScreen
import com.cinegram.ui.screens.library.LibraryViewModel
import com.cinegram.ui.screens.player.PlayerScreen
import com.cinegram.ui.screens.player.PlayerViewModel
import com.cinegram.ui.screens.settings.SettingsScreen
import com.cinegram.ui.screens.settings.SettingsViewModel
import com.cinegram.ui.theme.CinegramTheme
import com.cinegram.ui.theme.DarkBackground
import com.cinegram.ui.theme.ElectricCyan
import com.cinegram.ui.theme.TextSecondary
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CinegramTheme {
                MainAppScreen()
            }
        }
    }
}

@Composable
fun MainAppScreen() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route ?: "home"

    val showBottomBar = currentRoute == "home" || currentRoute == "library" || currentRoute == "settings"

    Scaffold(
        modifier = Modifier.fillMaxSize().background(DarkBackground),
        bottomBar = {
            if (showBottomBar) {
                GlassBottomBar {
                    BottomNavItem(
                        icon = Icons.Default.Home,
                        label = "Home",
                        isSelected = currentRoute == "home",
                        onClick = {
                            if (currentRoute != "home") {
                                navController.navigate("home") {
                                    popUpTo("home") { inclusive = false }
                                }
                            }
                        }
                    )
                    BottomNavItem(
                        icon = Icons.Default.List,
                        label = "Library",
                        isSelected = currentRoute == "library",
                        onClick = {
                            if (currentRoute != "library") {
                                navController.navigate("library") {
                                    popUpTo("home") { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        }
                    )
                    BottomNavItem(
                        icon = Icons.Default.Settings,
                        label = "Settings",
                        isSelected = currentRoute == "settings",
                        onClick = {
                            if (currentRoute != "settings") {
                                navController.navigate("settings") {
                                    popUpTo("home") { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        }
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "home",
            modifier = Modifier.fillMaxSize()
        ) {
            composable("home") {
                val viewModel: HomeViewModel = hiltViewModel()
                HomeScreen(
                    viewModel = viewModel,
                    onNavigateToDetails = { mediaId ->
                        navController.navigate("detail/$mediaId")
                    },
                    onNavigateToLibrary = {
                        navController.navigate("library")
                    },
                    onNavigateToSettings = {
                        navController.navigate("settings")
                    },
                    modifier = Modifier.padding(paddingValues)
                )
            }
            
            composable("library") {
                val viewModel: LibraryViewModel = hiltViewModel()
                LibraryScreen(
                    viewModel = viewModel,
                    onNavigateToDetails = { mediaId ->
                        navController.navigate("detail/$mediaId")
                    },
                    modifier = Modifier.padding(paddingValues)
                )
            }

            composable("settings") {
                val viewModel: SettingsViewModel = hiltViewModel()
                SettingsScreen(
                    viewModel = viewModel,
                    onNavigateBack = {
                        navController.navigateUp()
                    },
                    modifier = Modifier.padding(paddingValues)
                )
            }

            composable(
                route = "detail/{mediaId}",
                arguments = listOf(navArgument("mediaId") { type = NavType.StringType })
            ) { backStackEntry ->
                val mediaId = backStackEntry.arguments?.getString("mediaId") ?: ""
                val viewModel: DetailViewModel = hiltViewModel()
                DetailScreen(
                    mediaId = mediaId,
                    viewModel = viewModel,
                    onNavigateBack = {
                        navController.navigateUp()
                    },
                    onPlayFile = { filePath ->
                        val encodedPath = java.net.URLEncoder.encode(filePath, "UTF-8")
                        navController.navigate("player?filePath=$encodedPath&mediaId=$mediaId")
                    }
                )
            }

            composable(
                route = "player?filePath={filePath}&mediaId={mediaId}",
                arguments = listOf(
                    navArgument("filePath") { type = NavType.StringType },
                    navArgument("mediaId") { type = NavType.StringType }
                )
            ) { backStackEntry ->
                val encodedPath = backStackEntry.arguments?.getString("filePath") ?: ""
                val filePath = java.net.URLDecoder.decode(encodedPath, "UTF-8")
                val mediaId = backStackEntry.arguments?.getString("mediaId") ?: ""
                val viewModel: PlayerViewModel = hiltViewModel()
                
                PlayerScreen(
                    filePath = filePath,
                    mediaId = mediaId,
                    viewModel = viewModel,
                    onNavigateBack = {
                        navController.navigateUp()
                    }
                )
            }
        }
    }
}

@Composable
fun RowScope.BottomNavItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val tintColor = if (isSelected) ElectricCyan else TextSecondary
    Column(
        modifier = Modifier
            .weight(1f)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = tintColor,
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = tintColor,
            fontSize = 11.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
        )
    }
}
