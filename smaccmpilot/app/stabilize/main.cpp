// -*- Mode: C++; indent-tabs-mode: nil; c-basic-offset: 4 -*-
/*
 * main.cpp --- AP_HAL HIL based helicopter stabilizer
 *
 * Copyright (C) 2012, Galois, Inc.
 * All Rights Reserved.
 *
 * This software is released under the "BSD3" license.  Read the file
 * "LICENSE" for more information.
 */

#include <stdint.h>

#include <FreeRTOS.h>
#include <task.h>

#include <AP_HAL_SMACCM.h>
#include <AP_Math.h>

#include <smaccmpilot/userinput.h>
#include <smaccmpilot/motorsoutput.h>
#include <smaccmpilot/stabilize.h>
#include <smaccmpilot/gcs_receive.h>
#include <smaccmpilot/gcs_transmit.h>
#include <smaccmpilot/sensors.h>
#include <smaccmpilot/optflow_input.h>
#include <smaccmpilot/position_estimator.h>
#include <smaccmpilot/altitude_controller.h>
#include <smaccmpilot/horizontal_controller.h>
#include <smaccmpilot/ioar_relay.h>

const AP_HAL::HAL& hal = AP_HAL_BOARD_DRIVER;

// Handle to the main thread.
static xTaskHandle g_main_task;

// Initialize the HAL and sub-tasks before the main loop.
void init(void)
{
    hal.init(0, NULL);

    userinput_init();
#ifndef USE_HIL
    sensors_init();
#endif
    motorsoutput_init();
    gcs_receive_init();
    gcs_transmit_init();

    optflow_input_init();
    ioar_relay_init();

    userinput_start_task();
#ifndef USE_HIL
    sensors_start_task();
#endif
    motorsoutput_start_task();
    gcs_receive_start_task();
    gcs_transmit_start_task();

    optflow_input_start_task();
    
    ioar_relay_start_task();

    ioar_relay_set(IOAR_RELAY_BLINK_FAST);
}

// Main thread.  Starts up the GCS thread to communicate with the
// host, then processes incoming sensor data and writes servo output
// back to MAVLink.
void main_task(void *arg)
{
    struct userinput_result userinput;
    struct userinput_result altitude_comped_input;
    struct userinput_result althoriz_comped_input;
    struct sensors_result sensors;
    struct motorsoutput_result motors;
    struct position_result gps_position;
    struct position_result fromestimated_position;
    struct position_estimate pos_estimate;
    struct servo_result servos;
    struct optflow_result optflow;

    init();
    memset(&gps_position, 0, sizeof(gps_position));
    portTickType last_wake_time = xTaskGetTickCount();

    for (;;) {
        userinput_get(&userinput);

#ifdef USE_HIL
        gcs_receive_get_hilstate(&sensors, &gps_position);
#else
        sensors_get(&sensors);
        optflow_input_get(&optflow);
#endif

        if (!sensors.valid) {
            userinput.armed = false;
        }

        position_estimate(&sensors, &gps_position, &optflow, &pos_estimate);

        altitude_compensate(&pos_estimate, &sensors, &userinput,
                &altitude_comped_input);

        horizontal_compensate(&pos_estimate, &sensors, &altitude_comped_input,
                &althoriz_comped_input);

        stabilize_motors(&althoriz_comped_input, &sensors, &motors);

        motorsoutput_set(&motors);

        motorsoutput_getservo(&servos);

        position_estimate_output(&pos_estimate, &fromestimated_position);

        gcs_transmit_set_states(&sensors, &fromestimated_position,
                &motors, &servos, &althoriz_comped_input);

        if (!(userinput.armed)){
            ioar_relay_set(IOAR_RELAY_PULSE_SLOW);
        } else if (altitude_comped_input.mode == 0)  { /* stabilize */
            ioar_relay_set(IOAR_RELAY_PULSE_FAST);
        } else if (altitude_comped_input.mode == 1) { /* alt_hold */
            ioar_relay_set(IOAR_RELAY_BLINK_FAST);
        } else if (altitude_comped_input.mode == 2) { /* loiter */
            ioar_relay_set(IOAR_RELAY_ON);
        } else { /* Error!! */
            ioar_relay_set(IOAR_RELAY_PULSE_EXTRA_FAST);
        }

        vTaskDelayUntil(&last_wake_time, 10);
    }
}

extern "C"
int main()
{
    xTaskCreate(main_task, (signed char *)"main", 1024, NULL, 0, &g_main_task);
    vTaskStartScheduler();

    for (;;)
        ;

    return 0;
}
