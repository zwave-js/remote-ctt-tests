#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2022 Silicon Laboratories Inc. <https://www.silabs.com/>
#
# SPDX-License-Identifier: BSD-3-Clause

import socket
import struct
import binascii
import threading
import errno
import argparse
import select
import signal
import enum


class ZpalRegion(enum.IntEnum):
    EU = 0                 # EU. 2 Channel region.
    US = 1                 # US. 2 Channel region.
    ANZ = 2                # Australia/New Zealand. 2 Channel region.
    HK = 3                 # Hong Kong. 2 Channel region.
    IN = 5                 # India. 2 Channel region.
    IL = 6                 # Israel. 2 Channel region.
    RU = 7                 # Russia. 2 Channel region.
    CN = 8                 # China. 2 Channel region.
    US_LR = 9              # US. 2 Channel LR region.
    US_LR_BACKUP = 10      # DEPRECATED US. 2 Channel LR Backup region.
    EU_LR = 11             # EU. 2 Channel LR region.
    JP = 32                # Japan. 3 Channel region.
    KR = 33                # Korea. 3 Channel region.
    US_LR_END_DEVICE = 48  # DEPRECATED US Long Range End Device. 2 Long Range Channel Region.
    DEFAULT = 0xFF         # EU. 2 Channel region.

zpal_region_is_lr_map = {
    ZpalRegion.EU: False,
    ZpalRegion.US: False,
    ZpalRegion.ANZ: False,
    ZpalRegion.HK: False,
    ZpalRegion.IN: False,
    ZpalRegion.IL: False,
    ZpalRegion.RU: False,
    ZpalRegion.CN: False,
    ZpalRegion.US_LR: True,
    ZpalRegion.US_LR_BACKUP: True,
    ZpalRegion.EU_LR: True,
    ZpalRegion.JP: False,
    ZpalRegion.KR: False,
    ZpalRegion.US_LR_END_DEVICE: True,
    ZpalRegion.DEFAULT: False,
}

class PtiRegion(enum.IntEnum):
    EU = 0x01
    US = 0x02
    ANZ = 0x03
    HK = 0x04
    MY = 0x05
    IN = 0x06
    JP = 0x07
    RU = 0x08
    IL = 0x09
    KR = 0x0A
    CN = 0x0B
    US_LR1 = 0x0C
    US_LR2 = 0x0D
    US_LR3 = 0x0E
    EU_LR1 = 0x0F
    EU_LR2 = 0x10
    EU_LR3 = 0x11


zpal_to_pti_region_map = {
    ZpalRegion.EU: PtiRegion.EU,
    ZpalRegion.US: PtiRegion.US,
    ZpalRegion.ANZ: PtiRegion.ANZ,
    ZpalRegion.HK: PtiRegion.HK,
    ZpalRegion.IN: PtiRegion.IN,
    ZpalRegion.IL: PtiRegion.IL,
    ZpalRegion.RU: PtiRegion.RU,
    ZpalRegion.CN: PtiRegion.CN,
    ZpalRegion.US_LR: PtiRegion.US_LR1,
    ZpalRegion.US_LR_BACKUP: PtiRegion.US_LR2,
    ZpalRegion.EU_LR: PtiRegion.EU_LR1,
    ZpalRegion.JP: PtiRegion.JP,
    ZpalRegion.KR: PtiRegion.KR,
    ZpalRegion.US_LR_END_DEVICE: PtiRegion.US_LR3,
    ZpalRegion.DEFAULT: PtiRegion.EU,
}

# Simulator use Z-Wave channel from 0 to 4 (0-2> classic Z-Wave, 3&4> LR Z-Wave)
# However, PTI is based on Silicon Labs' RAIL which does not use Z-Wave channel.
# PTI use only 4 differents RAIL_channels. Each of this RAIL_channels could be configured
# to any of Z-Wave channel (depending of the PtiRegion).
# So in case of LR frame:
# - convert z-wave region to pti channel configuration 3
# - convert z-wave channel 3/4 to pti channel 0/1
zpal_region_lr_to_pti_ch_cfg_3_map = {
    ZpalRegion.US_LR: PtiRegion.US_LR3,
    ZpalRegion.EU_LR: PtiRegion.EU_LR3,
}


class DiscoveryThread(threading.Thread):
    def __init__(self, serial):
        super().__init__()

        serial_no = binascii.hexlify(struct.pack('<I', int(serial))).decode()

        self._event = threading.Event()
        self._socket = None
        self._discover_response = binascii.unhexlify(f'466f756e6400000000000000000000000000000000000000000000000000000000000000000000000101000000000000{serial_no}409c00002c010000000000004a2d4c696e6b2050726f204f42000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000')
        self._discover_ex_response = binascii.unhexlify(f'466f756e6400000000000000000000000000000000000000000000000000000000000000000000000101000000000000{serial_no}409c00002c010000000000004a2d4c696e6b2050726f204f4200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000053696c69636f6e204c616273204a2d4c696e6b2050726f204f4220636f6d70696c65642053657020313620323032302031373a31303a353800436f7079726967687420323031362053696c69636f6e204c6162733a207777772e73696c6162732e636f6d000000000000000000000000ff01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000')

    def _handle_msg(self, message, address):
        DISCOVER_MSG = b'Discover'
        DISC_EX_MSG = b'DiscEx'
        if message[:len(DISCOVER_MSG)] == DISCOVER_MSG:
            print('Discover frame')
            self._socket.sendto(self._discover_response, address)
        elif message[:len(DISC_EX_MSG)] == DISC_EX_MSG:
            print('DiscEx frame')
            self._socket.sendto(self._discover_ex_response, address)
        else:
            print(message, address)

    def _run(self):
        return not self._event.is_set()

    def stop(self):
        self._event.set()
        try:
            self._socket.shutdown(socket.SHUT_RDWR)
        except socket.error as e:
            err = e.args[0]
            if err != errno.ENOTCONN:
                raise

    def run(self):
        while self._run():
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self._socket.bind(('', 19020))

            while self._run():
                try:
                    select.select([self._socket], [], [])
                    if not self._run():
                        break
                    message, address = self._socket.recvfrom(1024, socket.MSG_DONTWAIT)
                    self._handle_msg(message, address)
                except socket.error as e:
                    err = e.args[0]
                    if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                        pass
                    else:
                        print(e)
                        break
            self._socket.close()


class ZnifferThread(threading.Thread):
    def __init__(self):
        super().__init__()
        self._event = threading.Event()
        self._udp_socket = None
        self._tcp_socket = None

    def _run(self):
        return not self._event.is_set()

    def stop(self):
        self._event.set()
        try:
            self._tcp_socket.shutdown(socket.SHUT_RDWR)
        except socket.error as e:
            err = e.args[0]
            if err != errno.ENOTCONN:
                raise

    def _prepare_pti_frame(self, data):
        pid, speed, zwave_channel, region, rssi = struct.unpack('<IBBBb', data[:8])
        payload = data[8:]

        zpal_region = ZpalRegion(region)

        # Simulator use Z-Wave channel from 0 to 4 (0-2> classic Z-Wave, 3&4> LR Z-Wave)
        # However, PTI is based on Silicon Labs' RAIL which does not use Z-Wave channel.
        # PTI use only 4 differents RAIL_channels. Each of this RAIL_channels could be configured
        # to any of Z-Wave channel (depending of the PtiRegion).
        # So in case of LR frame:
        # - convert z-wave region to pti channel configuration 3
        # - convert z-wave channel 3/4 to pti channel 0/1
        if zpal_region == ZpalRegion.US_LR_BACKUP and zwave_channel == 3 :
            # backward compatibility: previously, simulator was using US_LR_BACKUP region with channel 3
            pti_region = PtiRegion.US_LR3
            pti_channel = 1
        elif zpal_region_is_lr_map[zpal_region] == True and zwave_channel == 3 :
            # LR frame on channel LR_A
            pti_region = zpal_region_lr_to_pti_ch_cfg_3_map[zpal_region]
            pti_channel = 0
        elif zpal_region_is_lr_map[zpal_region] == True and zwave_channel == 4 :
            # LR frame on channel LR_B
            pti_region = zpal_region_lr_to_pti_ch_cfg_3_map[zpal_region]
            pti_channel = 1
        else :
            # classic Z-Wave frame
            # also backward compatibility (simulator was using US_LR_END_DEVICE with channel 0 a 1)
            pti_region = zpal_to_pti_region_map[zpal_region]
            pti_channel = zwave_channel

        payload_len = len(payload)
        pti_frame_len = 12 + 1 + payload_len + 7
        pti_frame = [0x5B, pti_frame_len]
        pti_frame.extend([0x00] * 12)
        pti_frame.extend([0xF8])
        pti_frame.extend(payload)
        pti_frame.extend([0xF9, rssi & 0xFF, pti_region, pti_channel, 0x06, 0x51, 0x5D])
        return bytearray(pti_frame)

    def _check_zniffer_conn(self, conn):
        try:
            tcp_data = conn.recv(1024, socket.MSG_DONTWAIT)
            if len(tcp_data) == 0:
                return False
        except socket.error as e:
            err = e.args[0]
            if err == errno.ECONNRESET:
                print('tcp reset')
                return False
            elif err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                pass
            else:
                print(e)
        return True

    def _handle_zne(self, conn):
        try:
            data = self._udp_socket.recv(1024, socket.MSG_DONTWAIT)
            if data:
                pti_frame = self._prepare_pti_frame(data)
                conn.sendall(pti_frame)
        except socket.error as e:
            err = e.args[0]
            if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                pass
            else:
                print(e)

    def run(self):
        MCAST_GRP = '224.0.0.0'
        MCAST_PORT = 4321

        self._udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        self._udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._udp_socket.bind((MCAST_GRP, MCAST_PORT))
        mreq = struct.pack('4sl', socket.inet_aton(MCAST_GRP), socket.INADDR_ANY)
        self._udp_socket.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)

        self._tcp_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._tcp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._tcp_socket.setblocking(False)
        self._tcp_socket.bind(('', 4905))
        self._tcp_socket.listen(0)

        print('Waiting for connection...')
        while self._run():
            try:
                select.select([self._tcp_socket], [], [])
                if not self._run():
                    break
                conn, addr = self._tcp_socket.accept()
            except socket.error as e:
                err = e.args[0]
                if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                    pass
                else:
                    print(e)
                continue

            with conn:
                print(f'Connected by {addr}')
                while self._run():
                    rd, wr, ex = select.select([self._udp_socket, self._tcp_socket], [], [self._udp_socket, self._tcp_socket], 0.1)
                    if not self._check_zniffer_conn(conn):
                        break
                    if self._udp_socket in rd:
                        self._handle_zne(conn)
            if self._run():
                print('Waiting for connection...')

        self._udp_socket.close()
        self._tcp_socket.close()


def signal_handler(sig, frame):
    pass


parser = argparse.ArgumentParser()
parser.add_argument('serial', help='Serial number')

args = parser.parse_args()

signal.signal(signal.SIGINT, signal_handler)
print('Press Ctrl+C to stop\n')

dt = DiscoveryThread(args.serial)
zt = ZnifferThread()
dt.start()
zt.start()

signal.pause()

dt.stop()
zt.stop()