package main
// vim: set ft=go noet ai ts=4 sw=4 sts=4:

import (
	"fmt"
	"net"
	"time"
	"net/http"
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

// create a handler struct
type HttpHandler struct{}

// implement `ServeHTTP` method on `HttpHandler` struct
func (h HttpHandler) ServeHTTP(res http.ResponseWriter, req *http.Request) {
	// create response binary data
	data := []byte("Unreachable\n") // slice of bytes

	if result {
		data = []byte("Reachable\n")
	}

	// write data to response
	res.Write(data)
}


func main() {
	// spawn goroutine, it "backgrounds" automatically
	go mycheck()

	// create a new handler
	handler := HttpHandler{}
	// listen and serve
	e := http.ListenAndServe("127.0.0.1:9000", handler)

	if e != nil {
		fmt.Println(e)
	}
}
