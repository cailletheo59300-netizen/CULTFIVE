package app.brainlix.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.brainlix.android.design.BrainlixTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val app = application as BrainlixApplication
        setContent {
            BrainlixTheme {
                FoundationScreen(app)
            }
        }
    }
}
