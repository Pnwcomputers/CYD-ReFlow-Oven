// TFT_eSPI setup for the Elecrow CrowPanel 2.8" ESP32 HMI (also sold as the
// Elecrow 2.8" ESP32 "Solo Miner" display). Values from Elecrow's bundled
// TFT_eSPI/User_Setup.h for this board.
//
// Use: copy this file over libraries/TFT_eSPI/User_Setup.h (keep a backup of
// the original), or #include it from User_Setup_Select.h.
#define USER_SETUP_INFO "CrowPanel 2.8"

#define ILI9341_DRIVER
#define TFT_WIDTH  240
#define TFT_HEIGHT 320

#define TFT_MISO 12
#define TFT_MOSI 13
#define TFT_SCLK 14
#define TFT_CS   15
#define TFT_DC    2
#define TFT_RST  -1
#define TFT_BL   27
#define TFT_BACKLIGHT_ON HIGH

#define TOUCH_CS 33

#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF
#define SMOOTH_FONT

#define SPI_FREQUENCY       15999999
#define SPI_READ_FREQUENCY  20000000
#define SPI_TOUCH_FREQUENCY   600000
