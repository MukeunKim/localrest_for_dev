module test;

import vibe.data.json;
import geod24.LocalRest;
static import C = geod24.concurrency;
import std.stdio;
import core.sync.mutex;
import core.thread;
import std.datetime.systime;
import std.variant;

import vibe.core.core;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;

/*
void main()
{
    static interface API
    {
        @safe:
        public @property ulong pubkey ();
        public Json getValue (ulong idx);
        public Json getQuorumSet ();
        public string recv (Json data);
    }

    static class MockAPI : API
    {
        @safe:
        public override @property ulong pubkey ()
        {
            return 42;
        }
        public override Json getValue (ulong idx)
        { assert(0); }
        public override Json getQuorumSet ()
        { assert(0); }
        public override string recv (Json data)
        { assert(0); }
    }

    import std.stdio;

    scope test = RemoteAPI!API.spawn!MockAPI();
    assert(42 == test.pubkey());
    test.ctrl.shutdown();

}
*/
void main()
{
    //test0();
    test14();
    //test15();

    //writefln("%s", Duration.init);
}

void test0()
{
    import std.container;
    import std.algorithm;
    import std.stdio;
    import std.range : popFrontN, popBackN, walkLength;
    struct MyData
    {
        string name;
        int age;
    }

    DList!MyData data;

    data.insertBack(MyData("Kim", 10));
    data.insertBack(MyData("Lee", 11));
    data.insertBack(MyData("Park", 12));

    auto r = find(data[], MyData("Lee", 11));
    if (!r.empty)
    {
        popBackN(r, r.walkLength-1);
        writefln("%s", r);
        data.remove(r);
        writefln("%s", data[]);
    }
}

void test1()
{
    writeln("test1 1");
    static interface API
    {
        @safe:
        public @property ulong pubkey ();
        public Json getValue (ulong idx);
        public Json getQuorumSet ();
        public string recv (Json data);
    }

    static class MockAPI : API
    {
        @safe:
        public override @property ulong pubkey ()
        { return 42; }
        public override Json getValue (ulong idx)
        { assert(0); }
        public override Json getQuorumSet ()
        { assert(0); }
        public override string recv (Json data)
        { assert(0); }
    }

    scope test = RemoteAPI!API.spawn!MockAPI();
    assert(test.pubkey() == 42);
    test.ctrl.shutdown();
    writeln("test1 2");
}

void test2()
{

    import std.stdio;
    writeln("test2 1");
    import std.conv;
    static import geod24.concurrency;

    static interface API
    {
        @safe:
        public @property ulong pubkey ();
        public Json getValue (ulong idx);
        public string recv (Json data);
        public string recv (ulong index, Json data);

        public string last ();
    }

    static class Node : API
    {
        @safe:
        public this (bool isByzantine) { this.isByzantine = isByzantine; }
        public override @property ulong pubkey ()
        { lastCall = `pubkey`; return this.isByzantine ? 0 : 42; }
        public override Json getValue (ulong idx)
        { lastCall = `getValue`; return Json.init; }
        public override string recv (Json data)
        { lastCall = `recv@1`; return null; }
        public override string recv (ulong index, Json data)
        { lastCall = `recv@2`; return null; }

        public override string last () { return this.lastCall; }

        private bool isByzantine;
        private string lastCall;
    }

    static RemoteAPI!API factory (string type, ulong hash)
    {
        const name = hash.to!string;
        auto tid = geod24.concurrency.locate(name);
        if (tid != tid.init)
            return new RemoteAPI!API(tid);

        switch (type)
        {
        case "normal":
            auto ret =  RemoteAPI!API.spawn!Node(false);
            geod24.concurrency.register(name, ret.tid());
            return ret;
        case "byzantine":
            auto ret =  RemoteAPI!API.spawn!Node(true);
            geod24.concurrency.register(name, ret.tid());
            return ret;
        default:
            assert(0, type);
        }
    }

    auto node1 = factory("normal", 1);
    auto node2 = factory("byzantine", 2);

    static void testFunc(geod24.concurrency.Tid parent)
    {
        auto node1 = factory("this does not matter", 1);
        auto node2 = factory("neither does this", 2);
        assert(node1.pubkey() == 42);
        assert(node1.last() == "pubkey");
        assert(node2.pubkey() == 0);
        assert(node2.last() == "pubkey");

        node1.recv(42, Json.init);
        assert(node1.last() == "recv@2");
        node1.recv(Json.init);
        assert(node1.last() == "recv@1");
        assert(node2.last() == "pubkey");
        node1.ctrl.shutdown();
        node2.ctrl.shutdown();
        geod24.concurrency.send(parent, Duration.init, 42);
    }
    writeln("test2, 2");

    auto testerFiber = geod24.concurrency.spawn(&testFunc, geod24.concurrency.thisTid);
    // Make sure our main thread terminates after everyone else
    geod24.concurrency.receiveOnly!int();
    import std.stdio;
    writeln("test2, 3");
}

void test3()
{
    import geod24.concurrency;

    static interface API
    {
        @safe:
        public @property ulong requests ();
        public @property ulong value ();
    }

    static class MasterNode : API
    {
        @safe:
        public override @property ulong requests()
        {
            return this.requests_;
        }

        public override @property ulong value()
        {
            this.requests_++;
            return 42; // Of course
        }

        private ulong requests_;
    }

    static class SlaveNode : API
    {
        @safe:
        this(Tid masterTid)
        {
            this.master = new RemoteAPI!API(masterTid);
        }

        public override @property ulong requests()
        {
            return this.requests_;
        }

        public override @property ulong value()
        {
            this.requests_++;
            return master.value();
        }

        private API master;
        private ulong requests_;
    }

    writeln("test3 - 1");
    RemoteAPI!API[4] nodes;
    auto master = RemoteAPI!API.spawn!MasterNode();
    nodes[0] = master;
    nodes[1] = RemoteAPI!API.spawn!SlaveNode(master.tid());
    nodes[2] = RemoteAPI!API.spawn!SlaveNode(master.tid());
    nodes[3] = RemoteAPI!API.spawn!SlaveNode(master.tid());

    writeln("test3 - 2");
    foreach (n; nodes)
    {
    writefln("n %s", n);
        writefln("requests   --- %s", n.requests());
        writefln("value      --- %s", n.value());
    }

    writeln("test3 - 3");
    assert(nodes[0].requests() == 4);

    foreach (n; nodes[1 .. $])
    {
        writefln("value      --- %s", n.value());
        writefln("requests   --- %s", n.requests());
    }

    writeln("test3 - 4");
    assert(nodes[0].requests() == 7);
    import std.algorithm;
    nodes.each!(node => node.ctrl.shutdown());
    writeln("test3 - 9");
}

void test13()
{
    import std.stdio;
    writeln("test10");

    import core.thread;
    import std.exception;

    static interface API
    {
        float getFloat();
        size_t sleepFor (long dur);
    }

    static class Node : API
    {
        override float getFloat() { return 69.69; }
        override size_t sleepFor (long dur)
        {
            Thread.sleep(msecs(dur));
            return 42;
        }
    }

    // node with no timeout
    auto node = RemoteAPI!API.spawn!Node();
    assert(node.sleepFor(80) == 42);  // no timeout

    // node with a configured timeout
    auto to_node = RemoteAPI!API.spawn!Node(500.msecs);

    /// none of these should time out
    assert(to_node.sleepFor(10) == 42);
    assert(to_node.sleepFor(20) == 42);
    assert(to_node.sleepFor(30) == 42);
    assert(to_node.sleepFor(40) == 42);

    assertThrown!Exception(to_node.sleepFor(2000));
    Thread.sleep(2.seconds);  // need to wait for sleep() call to finish before calling .shutdown()
    import std.stdio;
    assert(cast(int)to_node.getFloat() == 69);

    to_node.ctrl.shutdown();
    node.ctrl.shutdown();

    import std.stdio;
    writeln("test10");
}

void test14()
{
    import std.stdio;
    writeln("test14 --- 1");
    static import geod24.concurrency;
    import std.exception;

    __gshared C.Tid node_tid;

    static interface API
    {
        void check ();
        int ping ();
    }

    static class Node : API
    {
        override int ping () { return 42; }

        override void check ()
        {
            auto node = new RemoteAPI!API(node_tid, 5000.msecs);
            assert(node.ping() == 42);
            // We need to return immediately so that the main thread
            // puts us to sleep
            geod24.LocalRest.runTask(() {
                //node.ctrl.sleep(200.msecs);
                assert(node.ping() == 42);
            });
        }
    }

    auto node_1 = RemoteAPI!API.spawn!Node(5000.msecs);
    auto node_2 = RemoteAPI!API.spawn!Node(5000.msecs);
    node_tid = node_2.tid;
    node_1.check();
    //writeln("test14 --- 2");
    node_1.ctrl.sleep(300.msecs);
    //writeln("test14 --- 3");
    assert(node_1.ping() == 42);
    //writeln("test14 --- 4");

    //Thread.sleep(dur!("msecs")(1000));
    node_1.ctrl.shutdown();
    node_2.ctrl.shutdown();

    import std.stdio;
    writeln("test14 --- 5");
}

void test15()
{
    import std.stdio;
    writeln("test15");
    import std.exception;

    static interface API
    {
        int myping (int value);
    }

    static class Node : API
    {
        override int myping (int value)
        {
            return value;
        }
    }

    auto node = RemoteAPI!API.spawn!Node(1.seconds);
    assert(node.myping(42) == 42);
    node.ctrl.shutdown();

    try
    {
        node.myping(69);
        assert(0);
    }
    catch (Exception ex)
    {
        assert(ex.msg == `"Request timed-out"`);
    }
    import std.stdio;
    writeln("test15");
}