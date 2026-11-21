#pragma once
typedef int gpio_num_t;
enum { GPIO_DRIVE_CAP_3 = 3 };
inline int gpio_set_drive_capability(gpio_num_t, int) { return 0; }
