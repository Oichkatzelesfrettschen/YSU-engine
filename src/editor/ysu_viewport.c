#include "raylib.h"
#include "raymath.h"
#include <math.h>
#include <stdio.h>

// GPU rendering context (forward declarations)
// In production, these would link to gpu_vulkan_demo.c
extern int ysu_gpu_init(int width, int height);
extern int ysu_gpu_render_frame(const float *cam_pos, const float *cam_dir, const float *cam_up, float fov);
extern void ysu_gpu_shutdown(void);
extern unsigned char* ysu_gpu_get_framebuffer(void);  // Returns RGBA8 data

int main(void)
{
    const int screenWidth  = 1280;
    const int screenHeight = 720;

    InitWindow(screenWidth, screenHeight, "YSU Realtime Viewport");
    SetTargetFPS(60);

    // Initialize GPU rendering
    int gpu_enabled = ysu_gpu_init(screenWidth, screenHeight);
    if(!gpu_enabled) {
        printf("Warning: GPU rendering unavailable, using CPU fallback\n");
    }

    Vector3 target = { 0.0f, 1.0f, 0.0f };
    float distance = 6.0f;
    float yaw = 0.0f;
    float pitch = 0.35f;

    Camera3D cam = {0};
    cam.position   = (Vector3){ 0.0f, 2.0f, -distance };
    cam.target     = target;
    cam.up         = (Vector3){ 0.0f, 1.0f, 0.0f };
    cam.fovy       = 60.0f;
    cam.projection = CAMERA_PERSPECTIVE;

    Vector2 lastMouse = {0};
    int rotating = 0;
    const float sens = 0.005f;
    int use_gpu_render = gpu_enabled;  // Toggle with 'G' key

    while (!WindowShouldClose())
    {
        // Toggle GPU rendering with 'G' key
        if(IsKeyPressed(KEY_G) && gpu_enabled) {
            use_gpu_render = !use_gpu_render;
        }

        // Zoom
        float wheel = GetMouseWheelMove();
        distance -= wheel * 0.5f;
        if (distance < 1.5f) distance = 1.5f;
        if (distance > 30.0f) distance = 30.0f;

        // Orbit
        if (IsMouseButtonDown(MOUSE_BUTTON_LEFT) && IsKeyDown(KEY_LEFT_ALT))
        {
            Vector2 m = GetMousePosition();
            if (!rotating) { rotating = 1; lastMouse = m; }
            else
            {
                Vector2 d = { m.x - lastMouse.x, m.y - lastMouse.y };
                lastMouse = m;

                yaw   -= d.x * sens;
                pitch -= d.y * sens;

                float limit = 1.55f;
                if (pitch >  limit) pitch =  limit;
                if (pitch < -limit) pitch = -limit;
            }
        }
        else rotating = 0;

        // Update camera
        float cp = cosf(pitch);
        cam.position.x = target.x + distance * cp * cosf(yaw);
        cam.position.y = target.y + distance * sinf(pitch);
        cam.position.z = target.z + distance * cp * sinf(yaw);
        cam.target = target;

        BeginDrawing();
        ClearBackground((Color){ 18, 18, 24, 255 });

        if(use_gpu_render && gpu_enabled) {
            // GPU rendering path - render to GPU framebuffer and display
            float cam_pos[] = {cam.position.x, cam.position.y, cam.position.z};
            Vector3 cam_dir_v = Vector3Normalize(Vector3Subtract(cam.target, cam.position));
            float cam_dir[] = {cam_dir_v.x, cam_dir_v.y, cam_dir_v.z};
            float cam_up[] = {cam.up.x, cam.up.y, cam.up.z};
            
            // Render one frame on GPU
            if(ysu_gpu_render_frame(cam_pos, cam_dir, cam_up, cam.fovy) == 0) {
                unsigned char* fb = ysu_gpu_get_framebuffer();
                if(fb) {
                    // Display GPU framebuffer as texture
                    Image img = {
                        .data = fb,
                        .width = screenWidth,
                        .height = screenHeight,
                        .mipmaps = 1,
                        .format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
                    };
                    Texture2D tex = LoadTextureFromImage(img);
                    DrawTexture(tex, 0, 0, WHITE);
                    UnloadTexture(tex);
                }
            }
        } else {
            // CPU/raylib rendering path
            BeginMode3D(cam);

            DrawGrid(20, 1.0f);
            DrawCube((Vector3){0,0.5f,0}, 1,1,1, BLUE);
            DrawSphere((Vector3){2,1,0}, 1, LIGHTGRAY);

            EndMode3D();
        }

        // UI overlay
        DrawText(use_gpu_render ? "GPU Rendering (G to toggle)" : "CPU Rendering (G to toggle)", 10, 10, 20, use_gpu_render ? GREEN : LIGHTGRAY);
        DrawText("YSU Viewport (ALT+LMB orbit, Wheel zoom)", 10, 35, 20, RAYWHITE);

        EndDrawing();
    }

    // Cleanup GPU rendering
    if(gpu_enabled) {
        ysu_gpu_shutdown();
    }

    CloseWindow();
    return 0;
}
