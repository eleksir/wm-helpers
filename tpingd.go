package main

import (
	"fmt"
	"net"
	"os"
	"time"
	"github.com/godbus/dbus/v5"
)

var pingres = false
var sleeptime time.Duration = 5
var charge = "[??% ? 00:00]"

func secondsToClock(inSeconds int64) string {
	hours := (inSeconds / 60) / 60
	minutes := inSeconds % 60

	str := fmt.Sprintf("%02d:%02d", hours, minutes)
	return str
}

func mycharge () {
	for true {
		conn, err := dbus.SystemBus()

		if err != nil {
			time.Sleep(sleeptime * time.Second)
			continue
		}

		defer conn.Close()

		obj := conn.Object("org.freedesktop.UPower", "/org/freedesktop/UPower/devices/battery_BAT0")
		percentage, err := obj.GetProperty("org.freedesktop.UPower.Percentage")

		if err != nil {
			conn.Close()
			time.Sleep(sleeptime * time.Second)
			continue
		}

		var pcharge int = int(percentage.Value().(float64))

		state, err := obj.GetProperty("org.freedesktop.UPower.State")

		if err != nil {
			conn.Close()
			time.Sleep(sleeptime * time.Second)
			continue
		}

		var status string = "?"
		var chtime string = "00:00"

		if state.Value().(uint32) == 1 {
			mytime, err := obj.GetProperty("org.freedesktop.UPower.TimeToFull")

			if err != nil {
				chtime = "00:00"
			} else {
				var seconds = mytime.Value().(int64)
				chtime = secondsToClock(seconds)
			}

			status = "▲"
		} else if state.Value().(uint32) == 2 {
			mytime, err := obj.GetProperty("org.freedesktop.UPower.TimeToEmpty")

			if err != nil {
				chtime = "00:00"
			} else {
				var seconds = mytime.Value().(int64)
				chtime = secondsToClock(seconds)
			}

			status = "▼"
		} else if state.Value().(uint32) == 4 {
			status = "•"
		}

		charge = fmt.Sprintf("[%02d%% %s %s]\n", pcharge, status, chtime)
		time.Sleep(sleeptime * time.Second)
	}
}

func myping() {
	for true {
		conn, e := net.DialTimeout("tcp", "jenkins:443", 3000 * time.Millisecond)

		if e != nil {
			pingres = false
		} else {
			conn.Close()
			pingres = true
		}

		time.Sleep(sleeptime * time.Second)
	}
}

func handleConnection(conn net.Conn) {
	buf := make([]byte, 1024)
	bufLen, err := conn.Read(buf)

	if err == nil {
		tail := string(buf[bufLen - 4 : bufLen])

		// ah, fuck, yea. if you check buffer with \n\r\n\r against "\n\r\n\r" you'll get always FALSE, but if check against hex values, it works
		if bufLen > 4 && fmt.Sprintf("%x", tail) == "0d0a0d0a" {
			if pingres {
				var answer = fmt.Sprintf("HTTP/1.1 200 OK\nContent-Type: text/plain\nConnection: close\n\nReachable %s\n", charge)
				conn.Write([]byte(answer))
			} else {
				var answer = fmt.Sprintf("HTTP/1.1 200 OK\nContent-Type: text/plain\nConnection: close\n\nUnreachable %s\n", charge)
				conn.Write([]byte(answer))
			}

			conn.Close()
		} else {
			conn.Write([]byte("HTTP/1.1 400 Bad Request\nContent-Type: text/plain\nConnection: close\n\nBad Request\n"))
			conn.Close()
		}
	}
}

func main() {
	ln, e := net.Listen("tcp", "127.0.0.1:9000")

	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}

	go myping()
	go mycharge()

	for {
		// infinitely handle incomming connections
		conn, e := ln.Accept()

		if e != nil {
			// shit happens, let's try one more time
			continue
		}

		go handleConnection(conn)
	}
}
