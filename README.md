# RMServer_Sensor_Test
The automation of sensor testing on rack-mount servers using BASH and IPMI commands.

Written by Kevin SJ Huang 2019/1/16

## Script usage: ./sensor_test.sh <Sensor_Name> <Event_Reading_Mask>

This script has been tested and proven on Lenovo Purley rack-mount servers.

This script intends to run all kinds of BMC sensor assertion/deassertion tests with given sensor name and the event reading mask.

This script is NOT designed for sensor test that will need to reboot the system or with other triggering machanism.

This script is designed to run on RHEL7.

If sensor name contains spaces, use double quotes or it will be errors.
