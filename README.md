# Lambda RuntimesとLayersの仕組みを使ってPerlとMeCabで形態素解析をする

事業開発部の野村です。本記事は[AWS Lambda Custom Runtimes芸人 Advent Calendar 2018](https://qiita.com/advent-calendar/2018/lambda-custom-runtimes)の11日目の記事です。

## はじめに

先日のre:Invent 2018で発表した[Custom Runtimes](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html)。
社内でも早速アドベントカレンダーができるなどお祭り状態でしたので便乗してみました。

私はLambdaでPerlが実行できる環境と、MeCabを利用してリクエストが来た文章の形態素解析を行う関数の実装にチャレンジしました。
[AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)も使ってます。

まだ開発途中ではあるのですが備忘録も兼ねて残しておきます。

## 今回開発するもの

* LambdaのLayerにPerlと[MeCab](http://taku910.github.io/mecab/)の実行基盤を配置する
* 以下のリクエストにあるテキストを元に形態素解析を実施し、解析結果を返す関数をPerlで実装する

### リクエスト

```json
{
  "text": "形態素解析のテスト"
}
```

### レスポンス

```json
{
    "result" : [
      {
        "surface" : "形態素",
        "feature" : "名詞,一般,*,*,*,*,形態素,ケイタイソ,ケイタイソ",
        "cost" : 5338
      },
      {
        "feature" : "名詞,サ変接続,*,*,*,*,解析,カイセキ,カイセキ",
        "cost" : 9241,
        "surface" : "解析"
      },
      {
        "feature" : "助詞,連体化,*,*,*,*,の,ノ,ノ",
        "cost" : 10265,
        "surface" : "の"
      },
      {
        "cost" : 11987,
        "feature" : "名詞,サ変接続,*,*,*,*,テスト,テスト,テスト",
        "surface" : "テスト"
      },
      {
        "cost" : 11251,
        "feature" : "BOS/EOS,*,*,*,*,*,*,*,*",
        "surface" : "undef"
      }
    ]
}
```

## 前提

開発環境で以下を利用しています。

* macOS Mojave 10.14.1
* Docker version 18.09.0, build 4d60db4
* aws-cli 1.16.72

## ソース

[https://github.com/K1-Style/lambda-perl-mecab](https://github.com/K1-Style/lambda-perl-mecab) を使います。

```sh
$ git clone https://github.com/K1-Style/lambda-perl-mecab.git
$ cd lambda-perl-mecab
```

## PerlとMeCab実行基盤を作るためのDockerコンテナを用意

Dockerを使って、PerlとMeCabの実行基盤を作ります。Lambdaの実行環境と合わせるため [lambci/lambda](https://github.com/lambci/docker-lambda) をベースにしています。

```sh
$ docker run -it --name lambda-perl-mecab-container -v $(pwd):/var/task lambci/lambda:build ./install.sh
```

Perlで利用するMeCab用のライブラリText::MeCabのインストール時にmecab-configのファイルパスや利用する文字コードの入力待ちになるタイミングがあります。それぞれ以下を入力します。

```sh
Path to mecab config? /opt/bin/mecab-config
```

```sh
Encoding of your mecab dictionary? (shift_jis, euc-jp, utf-8) [euc-jp] utf-8
```

コンテナが出来たら、Lambda Layersのビルド作業に今後使うのでDockerイメージを作っておきます。

```sh
$ docker commit lambda-perl-mecab-container lambda-perl-mecab
```

イメージが出来たら、作ったコンテナは不要なので削除しても問題ありません。

```sh
$ docker rm lambda-perl-mecab-container
```

## Lambda Layers用のzipアーカイブを作る

先程作ったDockerイメージを使ってLambda Layers向けのzipアーカイブを作ります。

```sh
$ docker run --rm -it -v $(pwd):/var/task lambda-perl-mecab ./build-layer.sh
```

出来上がった`lambda-perl-mecab.zip`をLayerとして登録します。

```sh
$ aws --region $REGION --profile $PROFILE lambda publish-layer-version \
  --layer-name perl-mecab-layer \
  --zip-file fileb://lambda-perl-mecab.zip
```

## Lambda関数を用意

以下の`handler.pl`を用意し、こちらもzipアーカイブ化します。

```perl
use utf8;
use warnings;
use strict;
use Text::MeCab;
use Data::Dumper;

sub function {
    my ($payload) = @_;
    my $mecab = Text::MeCab->new();
    my @array;
    for (my $node = $mecab->parse($payload->{text}); $node; $node = $node->next) {
        my $word = {
        	surface => $node->surface,
        	feature => $node->feature,
        	cost => $node->cost,
        };
        push(@array, $word);
    }

    my $result = {
        result => \@array,
    };

    warn Dumper($result);

    return $result;
}

1;
```

```sh
$ zip handler.zip handler.pl
```

Lambda関数として登録します。

```sh
$ aws --region $REGION --profile $PROFILE lambda create-function \
  --function-name "lambda-perl-mecab-function" \
  --zip-file "fileb://handler.zip" \
  --handler "handler.function" \
  --runtime provided \
  --role arn:aws:iam::xxxxxxxxxxxx:role/service-role/lambda-custom-runtime-perl-role \
  --layers arn:aws:lambda:xxxxxxxx:xxxxxxxxxxxx:layer:perl-mecab-layer:1
```

* `--role`に指定するIAMロールは予め作成済みとします。
* `--layers`に先程作成したLayerのARNを入力します。

## テスト

以下で実行確認します。

```sh
$ aws --region $REGION --profile $PROFILE lambda invoke \
  --function-name "lambda-perl-mecab-function" \
  --payload '{"text":"形態素解析のテスト"}' \
  output.json
```

`output.json`にレスポンスとなるjsonが入りますが、現状日本語が文字化けしてます…
ここは引き続き調査します。

## 参考文献

今回の検証にあたり大いに参考にさせてもらいました。

* [Tutorial – Publishing a Custom Runtime \- AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html)
* [AWS Lambda Layers \- AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
* [aws\-lambda\-perl5\-layer 書いた \- その手の平は尻もつかめるさ](https://moznion.hatenadiary.com/entry/2018/12/01/113644)
* [PerlをAWS Lambdaで動かす](https://shogo82148.github.io/blog/2018/11/30/perl-in-lambda/)
* [MeCab: Yet Another Part\-of\-Speech and Morphological Analyzer](http://taku910.github.io/mecab/)
* [Text::MeCab \- Alternate Interface To libmecab \- metacpan\.org](https://metacpan.org/pod/Text::MeCab)

## さいごに

Lambda LayersやCustom Runtimesの仕組みを今回の実装や参考サイトを通して理解が深まりました。Lambdaでできることが随分と広がりましたね。

駆け足でざっと作ってしまいましたが、文字化けの件も含めもう少し検証して再度展開しようと思います。

それでは本日はこれにて。
