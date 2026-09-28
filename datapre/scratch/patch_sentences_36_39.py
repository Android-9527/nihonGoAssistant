# -*- coding: utf-8 -*-
import json, io, os

base = r"D:\project\nihonAssitant\datapre\language_data"

add = {
 36: [
   ("速く泳げるように、毎日練習しています。","为了能游得快，我每天都在练习。"),
   ("やっと自転車に乗れるようになりました。","我终于学会骑自行车了。"),
   ("毎日日記を書くようにしています。","我每天坚持写日记。"),
 ],
 37: [
   ("子どものとき、よく母にしかられました。","小时候，我经常被妈妈训斥。"),
   ("ラッシュの電車で足を踏まれました。","在拥挤的电车上，脚被人踩了。"),
   ("法隆寺は607年に建てられました。","法隆寺建于607年。"),
 ],
 38: [
   ("絵をかくのは楽しいです。","画画很开心。"),
   ("わたしは星を見るのが好きです。","我喜欢看星星。"),
   ("財布を持って来るのを忘れました。","我忘了带钱包来。"),
   ("わたしが日本へ来たのは去年の3月です。","我是去年3月来日本的。"),
 ],
 39: [
   ("ニュースを聞いて、びっくりしました。","听到新闻，吓了一跳。"),
   ("地震でビルが倒れました。","因为地震，大楼倒塌了。"),
   ("体の調子が悪いので、病院へ行きます。","因为身体不舒服，所以去医院。"),
 ],
}

stale_prefix = {36: "行2701-2705", 37: "行2881-2887", 38: "行3079-3083"}

for n, items in add.items():
    p = os.path.join(base, "chapter_%d.json" % n)
    d = json.load(io.open(p, encoding="utf-8"))
    for jp, zh in items:
        d["sentences"].append({"chapter": n, "sentence": jp, "chinese": zh})
    if n in stale_prefix:
        d["warnings"] = [w for w in d["warnings"] if not w.startswith(stale_prefix[n])]
    with io.open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
    print("ch%d sentences -> %d, warnings=%d" % (n, len(d["sentences"]), len(d["warnings"])))
