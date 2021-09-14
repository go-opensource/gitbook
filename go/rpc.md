## RPC
---
### RPC란?
* Remote procedure call
> 분산 컴퓨팅에서 RPC(원격 프로시저 호출)는 컴퓨터 프로그램이 프로시저(서브루틴)를 다른 주소 공간(일반적으로 공유 네트워크의 다른 컴퓨터에서)에서 실행하게 하는 것입니다.

### Client 알아보기
```
client, err := rpc.Dial("tcp", "localhost:42586")
if err != nil {
    log.Fatal(err)
}

in := bufio.NewReader(os.Stdin)
for {
    line, _, err := in.ReadLine()
    if err != nil {
        log.Fatal(err)
    }
    var reply bool
    err = client.Call("Listener.GetLine", line, &reply)
    if err != nil {
        log.Fatal(err)
    }
}
```
### Server 알아보기

```
type Listener struct {
	hi string
	Hi string
}

func (l *Listener) GetLine(line []byte, ack *bool) error {
	fmt.Println(string(line))
	return nil
}

// server
func main() {    
	addy, err := net.ResolveTCPAddr("tcp", "0.0.0.0:42586")
	if err != nil {
		log.Fatal(err)
	}

>	inbound, err := net.ListenTCP("tcp", addy)
	if err != nil {
		log.Fatal(err)
	}

	listener := new(Listener)
	listener.hi = "hi"
	listener.Hi = "Hi"	
>	rpc.Register(listener)
>	rpc.Accept(inbound)
}
```

#### net.ListenTCP
* tcp connection을 리턴해주는 go/net의 함수 rpc를 알아볼것이기에 tcp connection이라는것만 알고 패스

#### Register

```
//Register
func (server *Server) register(rcvr interface{}, name string, useName bool) error {
	s := new(service)
	s.typ = reflect.TypeOf(rcvr) // *main.Listener
	s.rcvr = reflect.ValueOf(rcvr) // &{hi Hi}
	sname := reflect.Indirect(s.rcvr).Type().Name() // Listener

...
...

>	s.method = suitableMethods(s.typ, true)

...
	
  // 2. load or store가 목적. syncmap인 servicemap에 load or store
>	if _, dup := server.serviceMap.LoadOrStore(sname, s); dup {
		return errors.New("rpc: service already defined: " + sname)
	}
	return nil
}

```
#### 1.Reflect
* register 함수에 server에 serving되기 원하는 실행되어질 structure와 method의 정보를 저장하기위해 service라는 객체를 만들고,
```
type service struct {
	name   string                 // name of service
	rcvr   reflect.Value          // receiver of methods for the service
	typ    reflect.Type           // type of the receiver
	method map[string]*methodType // registered methods (args,reply...)
}
```

* relfect를 통해 어떤타입인지, 값은 무엇인지, 이름은 무엇인지 등을 발라낸다. 
발라진 정보를 통해 server객체 내부에 특정이름과 함수실행을 위한 정보가 저장된다. 

#### 2.SuitableMethods
* suitableMethods는 type정보를 기반으로 넘겨받은 structure 내부의 methods들의 정보들을 발라내고 아래같은 예외처리들을 발라낸다.

```
log.Printf("rpc.Register: method %q has %d input parameters; needs exactly three\n", mname, mtype.NumIn())
log.Printf("rpc.Register: argument type of method %q is not exported: %q\n", mname, argType)
```

* method에서는 아래와 같은 형태로 service의 method로 저장된다.

```
suitableMethods Reuslt:
s.method["GetLine"]= 
   method:{method:{GetLine  func(*main.Listener, []uint8, *bool) error <func(*main.Listener, []uint8, *bool) error Value> 0}
   argtype: []uint8  
   replyType: *bool

```
* 이때 byte type이 uint8로 형태로 저장되는데, byte는 uint8의 alias형태일뿐 사이즈가 같다.([[]byte 정의 ](https://pkg.go.dev/builtin))
* 발라진 methods들은  server내부의 methods필드에 저장된다.


#### 3.LoadOrStore
* register에서 최종 목표는 LoadOrStore인데, server의 sync map 객체인 serviceMap에 위에서 만들어진 최종 servie 객체를 sname 즉 structture name으로 저장한다.
후에 client로부터 요청이오면 요청의 name을 보고 serviceMap에서 매칭되는 structure를 찾아 해당 function을 실행해준다.