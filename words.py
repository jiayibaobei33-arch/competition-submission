import argparse, requests, time
from pythonosc.udp_client import SimpleUDPClient

# 1) Choose your word source:
#    For zero-config demos we use Datamuse (syn/ant). Replace with your LLM later.
def get_syn_ant(keyword, maxn=8):
    base = "https://api.datamuse.com/words"
    syn = requests.get(base, params={"rel_syn": keyword, "max": maxn}).json()
    ant = requests.get(base, params={"rel_ant": keyword, "max": maxn}).json()
    return [w["word"] for w in syn], [w["word"] for w in ant]

# 2) Map word sets -> audio params (match your ChucK mapping)
def compute_params(synW, antW):
    # weights are counts; you can weight by LLM scores if you have them
    def clamp(v, lo, hi): return max(lo, min(hi, v))
    density = clamp(0.35 + 0.08*synW - 0.06*antW, 0.05, 0.95)
    tempo   = int(clamp(88 + 4*synW - 3*antW, 60, 150))
    bright  = clamp(0.40 + 0.12*synW - 0.10*antW, 0.0, 1.0)
    pan     = clamp((synW - antW)/6.0, -1.0, 1.0)
    return tempo, density, bright, pan

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("keyword", help="seed word")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=6449)
    args = ap.parse_args()

    client = SimpleUDPClient(args.host, args.port)

    # fetch words
    syns, ants = get_syn_ant(args.keyword)
    # clear lists on ChucK
    client.send_message("/clear", [])
    time.sleep(0.05)
    # send words
    for w in syns: client.send_message("/syn", w)
    for w in ants: client.send_message("/ant", w)

    # compute params and send
    tempo, density, bright, pan = compute_params(len(syns), len(ants))
    client.send_message("/params", [float(tempo), float(density), float(bright), float(pan)])

    print(f"Sent {len(syns)} syn, {len(ants)} ant -> tempo {tempo}, dens {density:.2f}, bright {bright:.2f}, pan {pan:.2f}")

if __name__ == "__main__":
    main()
