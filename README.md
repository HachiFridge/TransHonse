# TransHonse
My LLM Translation workflow rewritten in ruby because I felt like it and had fun.

![sick](https://media1.tenor.com/m/PvXxdLKkwTEAAAAd/umamusume-uma-musume.gif)

## Usage
Obviously you need ruby installed. Run ```bundle install``` to install all required gems.\
While these scripts are primarily written in ruby, the extract scripts are actually a ruby wrapper running unitypy.\
Therefore, you need python 3.8+ to run this as well as installing all required dependencies in requirements.txt via ```pip install requirements.txt``` or whatever.\
This was also made running on Windows 10, other OS I have no idea if it'll work

### Config
refer to ```config.toml``` file for an example of all required variables

### Extract Scripts
extract_mdb is used for extracting mdb based text such as character system text and text data dict
```
ruby extract_mdb.rb "master.mdb Path"
#usually the path is found at honse_game/honse_game_data/persistent/master/master.mdb
#I would recommend making a copy of this in your working directory
```

extract.rb works pretty much the same as umamusu-translate tools and accepts the same arguements\
technically required a decrypted mdb but it should be able to decrypt it on its own (maybe)\
\
you can also just run the following to extract all of the main files of interest
```
$env:UMA_DATA_DIR = "honse_game/honse_game_data/persistent" #set your honse game directory
ruby extract.rb -t story #pulls all story data
ruby extract.rb -t home #pulls all home interactions
```

or yknow you could just use the extract.py script like a normal person via python
```
$env:UMA_DATA_DIR = "honse_game/honse_game_data/persistent" #set your honse game directory
py extract.py # by default it will just extract all story files without any arguements
```

### Translate
expects you to have all the files extracted already\
works with story, home, and system character text files\
```
ruby translate.rb
```
you should get prompted with what kind of file you want to translate.\
Leave blank to run all files or specify.

### good talk
![tankhauser](http://matikanetannhauser.com/)
