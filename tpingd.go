package main

import (
	"fmt"
	"net"
	"os"
	"time"
)

var result = false

func mycheck() {
	for true {
		conn, e := net.DialTimeout("tcp", "jenkins:443", 3000 * time.Millisecond)

		if e != nil {
			result = false
		} else {
			conn.Close()
			result = true
		}

		time.Sleep(5 * time.Second)
	}
}

func handleConnection(conn net.Conn) {
	buf := make([]byte, 1024)
	bufLen, err := conn.Read(buf)

	if err == nil {
		tail := string(buf[bufLen - 4 : bufLen])

		// ah, fuck, yea. if you check buffer with \n\r\n\r against "\n\r\n\r" you'll get always FALSE, but if check against hex values, it works
		if bufLen > 4 && fmt.Sprintf("%x", tail) == "0d0a0d0a" {
			if result {
				conn.Write([]byte("HTTP/1.1 200 OK\nContent-Type: text/plain\nConnection: close\n\nReachable\n"))
			} else {
				conn.Write([]byte("HTTP/1.1 200 OK\nContent-Type: text/plain\nConnection: close\n\nUnreachable\n"))
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

	// spawn check goroutine
	go mycheck()

	for {
		conn, e := ln.Accept()

		if e != nil {
			// shit happens, let's try one more time
			continue
		}

		go handleConnection(conn)
	}
}
