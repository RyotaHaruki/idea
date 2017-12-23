#!/bin/bash

##################################
#
# アーカイブファイル展開ツール
#
#   Usage: jarmd5.sh sample.jar 2
#     入力
#       第１引数 : アーカイブファイルパス（*.ear,*.war,*.jarのみ）
#       第２引数 : 展開階層（0以上の数値のみ）
#     出力
#       展開結果ディレクトリ（実行時ディレクトリに「working_dir」を作成し、アーカイブファイルを展開する）
#       MD5ハッシュ値・更新日時・ファイルサイズ一覧ファイル（ファイル名は[アーカイブファイル名]_[展開階層]）
#
#   以下の処理を行う。
#
#     (1) アーカイブ展開 :
#         指定したアーカイブファイルを、指定した展開階層数分、再帰的に展開する。
#        （アーカイブファイル名をもとに作成したディレクトリ以下に展開する）
#         ※前提：jarコマンドで展開するため、javaがインストール済みであること
#
# 例) jarmd5.sh sample1.ear 2 を実行した場合に展開されるファイル群
#
#  sample1.ear            ---> 展開階層: 0
#   |
#   |- sample2.war        ---> 展開階層: 1
#   |    |
#   |    `- sample3.jar   ---> 展開階層: 2
#   |         |
#   |         `- Abcd.class -> アーカイブファイル以外は展開されない
#   |
#   `- dir1               ---> 展開階層: 1
#        |
#        |- sample4.jar   ---> 展開階層: 2
#        |    |
#        |    `- Efgh.class -> アーカイブファイル以外は展開されない
#        |
#        `- xxx.cfg       ---> アーカイブファイル以外は展開されない 
#
#     (2) MD5ハッシュ値・更新日時・ファイルサイズ一覧取得 :
#         アーカイブ展開で展開したディレクトリ以下のファイルのファイルパス、MD5ハッシュ値、更新日時、ファイルサイズの一覧を作成する。
#
##################################

#########################################################
#各種設定

#jarコマンドパス
JAR_DIR=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.151-5.b12.el7_4.x86_64/bin

#アーカイブファイルパス
ARCHIVE_PATH=$1
ARCHIVE_NAME=${1##*/}

#指定展開階層
MAX_DEPTH=$2

#作業用ディレクトリ
WORKING_DIR=working_dir

#実行ディレクトリ
EXECUTE_DIR=`pwd`

#ハッシュ値出力ファイル名
HASH_FILE=${ARCHIVE_NAME}_${MAX_DEPTH}.md5

#ファイルサイズ、タイムスタンプ用ファイル名
SIZE_TIMESTAMP=${ARCHIVE_NAME}_${MAX_DEPTH}_ls

#ハッシュ値・ファイルサイズ・タイムスタンプマージファイル
MERGE_FILE=${ARCHIVE_NAME}_${MAX_DEPTH}

#ハッシュ値出力ファイルを実行後に削除するフラグ（デフォルト：1　削除する）
HASH_FILE_DEL_FLG=1

#ファイルサイズ・タイムスタンプファイルを実行後に削除するフラグ（デフォルト：1　削除する）
SIZE_TIMESTAMP_DEL_FLG=1

#########################################################
#入力チェック

if [ $# -ne 2 ]; then
  echo "引数の数が不正です。" 1>&2
  echo "Usage: jarmd5.sh アーカイブファイルパス 展開階層数" 1>&2
  echo "Example: jarmd5.sh sample.jar 2" 1>&2
  exit 1
fi

#ファイル拡張子チェック
extension=${1##*.}
#拡張子チェック
if [ $extension != "ear" ] && [ $extension != "war" ] && [ $extension != "jar" ]; then
  echo "アーカイブファイルの拡張子は [ear], [war], [jar] のみ有効です。"
  exit 1
fi

#ファイル存在チェック
if [ ! -e $1 ]; then
  echo "アーカイブファイル[$1]が存在しません。"
  exit 1
fi

#########################################################
#展開処理

#作業用ディレクトリに展開対象のアーカイブをコピー
mkdir $WORKING_DIR
cp -p $ARCHIVE_PATH $WORKING_DIR
cd $WORKING_DIR

#作業ディレクトリのルートディレクトリパスを記憶
BASE_DIR=`pwd`

#指定階層分ループ
for curdepth in `seq 0 $MAX_DEPTH`
do
  #当該階層のディレクトリ名リスト取得
  dirlist=`find . -mindepth $curdepth -maxdepth $curdepth -type d` 
  for dir in $dirlist
  do
    #EAR,WAR,JARファイル名リスト取得
    file_list=`ls -F $dir | grep -e \\.ear$ -e \\.war$ -e \\.jar$`
    for obj_file in $file_list
    do
      #当該ディレクトリに移動
      cd ${BASE_DIR}/${dir}
      obj_filename=${obj_file%.*}
      obj_extension=${obj_file##*.}
      #ファイル名_拡張子のディレクトリ名作成
      obj_dir=${obj_filename}_${obj_extension}
      mkdir $obj_dir
      #作成したディレクトリにアーカイブ展開
      cd $obj_dir
      ${JAR_DIR}/jar -xf ../$obj_file
      #一旦作業ルートディレクトリに戻る
      cd $BASE_DIR
    done
  done
done

#################################################
#MD5 ハッシュ値ファイル作成

#ハッシュ値取得
find . -type f -exec md5sum -b {} \; > ${EXECUTE_DIR}/${HASH_FILE}

#ファイル更新日時、サイズ
find . -type f -ls > ${EXECUTE_DIR}/${SIZE_TIMESTAMP}

#シェル実行時のディレクトリに戻る
cd $EXECUTE_DIR

#ハッシュ値ファイルをソートした一時ファイル作成
cat ${HASH_FILE} | awk -F'*' '{print $2 " " $1}' | sort > tmp1

#ファイル更新日時、サイズをソートした一時ファイル作成
cat ${SIZE_TIMESTAMP} | awk -F' ' '{print $11 " " $7 " " $8 " " $9 " " $10}' | sort > tmp2

#一時ファイル結合
join tmp1 tmp2 > ${MERGE_FILE}

#################################################
#中間ファイル削除
rm tmp1 tmp2

#その他ファイル削除
if [[ $HASH_FILE_DEL_FLG -eq 1 ]]; then
  rm $HASH_FILE
fi

if [[ $SIZE_TIMESTAMP_DEL_FLG -eq 1 ]]; then
  rm  $SIZE_TIMESTAMP
fi

#########################################################
echo "処理成功"
exit 0

