package p

import "reflect"

type S struct{ A int }

func good(s S, n int) int {
	f := reflect.ValueOf(s).FieldByName("A")
	p := reflect.New(reflect.TypeOf(0))
	acc := 0
	for i := 0; i < n; i++ {
		acc += int(f.Int())
		_ = reflect.TypeOf(i).Kind()
		_ = p
	}
	return acc
}
