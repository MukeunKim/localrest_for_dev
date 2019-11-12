/+ dub.sdl:
	name "test"
	description "Tests vibe.d's std.concurrency integration"
	dependency "vibe-core" path="../"
+/
module test;

import vibe.data.json;
import geod24.LocalRest;
import std.stdio;
import geod24.concurrency;

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
        { return 42; }
        public override Json getValue (ulong idx)
        { assert(0); }
        public override Json getQuorumSet ()
        { assert(0); }
        public override string recv (Json data)
        { assert(0); }
    }
    
    import std.stdio;

    writeln("start");
    scope test = RemoteAPI!API.spawn!MockAPI();
    writeln("pubkey");
    ulong v;
    v = test.pubkey();
    writeln("end");
    test.ctrl.shutdown();
}
