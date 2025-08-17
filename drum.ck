// ---------- audio engine params ----------
global float g_tempo  => 96;      // bpm
global float g_density => 0.40;   // 0..1
global float g_bright  => 0.40;   // 0..1
global float g_pan     => 0.00;   // -1..1

// active words (for ChuGL HUD)
[ ] @=> string synWords[];
[ ] @=> string antWords[];

// ---------- OSC receiver ----------
OscRecv recv; 6449 => recv.port; recv.listen();
OscEvent e;
recv.event( "/params", "ffff" ) @=> OscEvent eParams; // tempo, density, bright, pan
recv.event( "/syn",    "s"   ) @=> OscEvent eSyn;     // one synonym per msg
recv.event( "/ant",    "s"   ) @=> OscEvent eAnt;     // one antonym per msg
recv.event( "/clear",  ""    ) @=> OscEvent eClear;   // clear word lists

fun void oscLoop() {
    while (true) {
        // wait on any
        e => now;
        while (eParams.nextMsg() != 0) {
            eParams.getf() => g_tempo;
            eParams.getf() => g_density;
            eParams.getf() => g_bright;
            eParams.getf() => g_pan;
        }
        while (eSyn.nextMsg() != 0) {
            string w; eSyn.getString() => w;
            synWords << w;
        }
        while (eAnt.nextMsg() != 0) {
            string w; eAnt.getString() => w;
            antWords << w;
        }
        while (eClear.nextMsg() != 0) {
            [ ] @=> synWords;
            [ ] @=> antWords;
        }
    }
}
spork ~ oscLoop();

// ---------- tiny drum synth ----------
fun void kick( time t, float bright ) {
    SinOsc o => ADSR env => Pan2 p => dac;
    0.9 => env.gain;
    0.001::second => env.attackTime;
    0.02::second  => env.decayTime;
    0.0           => env.sustainLevel;
    0.12::second  => env.releaseTime;

    100.0 + 80.0*bright => float f0;
    40.0  => float fend;
    f0 => o.freq;
    // pitch drop
    spork ~ fun() {
        f0 => float f;
        for (0 => int i; i < 40; i++) {
            (f - (f - fend) * (i/39.0)) => o.freq;
            0.003::second => now;
        }
    }();
    g_pan => p.pan;
    env.keyOn();
    t => now;
    0.15::second => now;
    env.keyOff();
}
fun void snare( time t, float bright ) {
    Noise n => BPF bp => ADSR env => Pan2 p => dac;
    1000.0 + 3000.0*bright => bp.freq;
    2.0 => bp.Q;
    0.5 => env.gain;
    0.001::second => env.attackTime;
    0.08::second  => env.decayTime;
    0.0           => env.sustainLevel;
    0.10::second  => env.releaseTime;
    g_pan => p.pan;
    env.keyOn();
    t => now;
    0.12::second => now;
    env.keyOff();
}

// scheduler: 8th notes; density controls hit prob
fun void clock() {
    0.05::second => now; // small start delay
    while (true) {
        (60.0 / g_tempo / 2.0)::second => dur step;
        now => time t;
        // step index (0..7) for simple patterns
        ((t / step) $ int) % 8 => int idx;
        // probability model: downbeats more kick, upbeats more snare
        (idx % 4 == 0) => int down;

        // kick
        (g_density + (down ? 0.25 : 0.0)) $ float => float pk;
        Math.min(1.0, Math.max(0.0, pk)) => pk;
        if (Math.rand2f(0.0, 1.0) < pk) spork ~ kick( now, g_bright );

        // snare
        (g_density - (down ? 0.05 : 0.0)) $ float => float ps;
        Math.min(1.0, Math.max(0.0, ps)) => ps;
        if (Math.rand2f(0.0, 1.0) < ps) spork ~ snare( now, g_bright );

        step => now;
    }
}
spork ~ clock();

// ---------- ChuGL HUD ----------
Machine.add("ChuGL.ck"); // make sure ChuGL is installed & on chuck --chugin-path
chugl.Window win;
win.open(720, 420, "LLM Syn/Ant Drum");
chugl.Canvas g;
g.font("monospace", 16);

fun void render() {
    while (true) {
        g.beginFrame();
        g.fill(1,1,1,1);
        g.rect(0,0, win.width(), win.height());

        g.fill(0,0,0,1);
        g.text(20, 30, "tempo: " + g_tempo + "  density: " + g_density + "  bright: " + g_bright + "  pan: " + g_pan);
        g.text(20, 60, "Synonyms:");
        for (0 => int i; i < synWords.size(); i++) g.text(40, 90 + 20*i, synWords[i]);

        g.text(320, 60, "Antonyms:");
        for (0 => int i; i < antWords.size(); i++) g.text(340, 90 + 20*i, antWords[i]);

        g.endFrame();
        1::ms => now;
    }
}
spork ~ render();

// keep alive
while (true) 1::second => now;
