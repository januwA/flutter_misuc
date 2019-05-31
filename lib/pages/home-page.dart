import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:flute_music_player/flute_music_player.dart';
import 'package:flutter_music/shared/widgets/empty_songs.dart';
import 'package:flutter_music/shared/widgets/song_title.dart';
import 'package:flutter_music/shared/widgets/page_loading.dart';
import 'package:flutter_music/shared/widgets/playing_song.dart';
import 'package:flutter_music/shared/widgets/overflow_text.dart';
import 'package:flutter_music/shared/widgets/song_slider.dart';
import 'package:flutter_music/src/app.service.dart';
import 'package:flutter_music/src/song.service.dart';
import 'package:flutter_music/src/home.service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

const int yoff = 3;

class HomePage extends StatefulWidget {
  HomePage({
    Key key,
    this.homeService,
    this.songService,
    this.appService,
  }) : super(key: key);

  final SongService songService;
  final HomeService homeService;
  final AppService appService;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  Animation<Offset> animation;
  AnimationController animationCtrl;
  bool _isGrid = false;
  SharedPreferences _prefs;

  @override
  void initState() {
    animationCtrl = new AnimationController(
      duration: const Duration(
        milliseconds: 600,
      ),
      vsync: this,
    );
    animation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, 1), // y轴偏移量+height
    ).animate(animationCtrl);

    _initTheme();
    super.initState();
  }

  _initTheme() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGrid = _prefs.getBool('isGrid') ?? false;
    });
  }

  @override
  void dispose() {
    animationCtrl.dispose();
    widget.songService.dispose();
    widget.homeService.dispose();
    widget.homeService.dispose();
    super.dispose();
  }

  /// 隐藏页面底部正在播放歌曲面板
  void _hide() {
    animationCtrl.forward();
  }

  /// 显示页面底部正在播放歌曲面板
  void _show() {
    animationCtrl.reverse();
  }

  /// 监听ListView滚动事件
  bool _onNotification(Notification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.depth == 0 &&
        widget.songService.playingSong != null) {
      var d = notification.dragDetails;
      if (d != null && d.delta != null) {
        var dy = d.delta.dy;
        if (dy > yoff) {
          // 手指向下滑动
          _show();
        } else if (dy < -yoff) {
          // 手指向上滑动
          _hide();
        }
      }
      return true;
    }
    return false;
  }

  /// Grid布局的每个item
  Widget _gridItemSong(Song song, int index) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: widget.songService.itemSongTap(song, index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SongTitle.grid(
              song,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 95,
            ),
            ListTile(
              title: OverflowText(song.title),
              subtitle: OverflowText(song.album),
            )
          ],
        ),
      ),
    );
  }

  Widget _homeGridView(List<Song> songs) {
    return GridView.count(
      crossAxisSpacing: 10.0,
      crossAxisCount: 2,
      children: <Widget>[
        for (Song song in songs) _gridItemSong(song, songs.indexOf(song)),
      ],
    );
  }

  Widget _homeListView(List<Song> songs) {
    return ListView.separated(
      separatorBuilder: (BuildContext context, int index) => Divider(
            indent: 8.0,
          ),
      itemCount: songs.length,
      itemBuilder: (context, int index) {
        Song tapSong = songs[index];
        return new ListTile(
          dense: true,
          leading: SongTitle(tapSong),
          title: OverflowText(tapSong.title),
          subtitle: OverflowText(tapSong.album),
          onTap: widget.songService.itemSongTap(tapSong, index),
        );
      },
    );
  }

  /// 返回头部的actions
  List<Widget> _appbarActions() {
    return [
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () {
          showSearch<String>(
            context: context,
            delegate: _SearchPage(
                widget.songService.songs, widget.songService.itemSongTap),
          );
        },
      ),
    ];
  }

  Widget _loadingSongs() {
    return PageLoading(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(),
          Text('加载本地歌曲信息中...'),
        ],
      ),
    );
  }

  Widget _headerDrawer() {
    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            padding: EdgeInsets.all(0.0),
            child: CachedNetworkImage(
              imageUrl: "https://s2.ax1x.com/2019/05/08/E6hGEn.md.jpg",
              placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(),
                  ),
              errorWidget: (context, url, error) => new Icon(Icons.error),
              fit: BoxFit.fill,
            ),
          ),
          ListTile(
            leading: Text(widget.appService.isDark ? 'Set Dark' : "Set Light"),
            trailing: Switch(
              activeColor: Theme.of(context).primaryColorDark,
              activeTrackColor: Theme.of(context).primaryColorLight,
              value: widget.appService.isDark,
              onChanged: widget.appService.setTheme,
            ),
          ),
          ListTile(
            leading: Text(_isGrid ? 'Set List' : "Set Grid"),
            trailing: IconButton(
              onPressed: () {
                setState(() {
                  _isGrid = !_isGrid;
                });
              },
              icon: Icon(_isGrid ? Icons.view_list : Icons.grid_on),
              color: Theme.of(context).primaryColorLight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Song>>(
      stream: widget.songService.songs,
      initialData: List<Song>(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return _loadingSongs();
        }
        final List<Song> songs = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(
                'Music [${widget.songService.currentIndex + 1}/${widget.songService.songLength}]'),
            actions: _appbarActions(),
          ),
          drawer: _headerDrawer(),
          body: songs.isEmpty
              ? EmptySongs()
              : Stack(
                  children: <Widget>[
                    NotificationListener(
                      onNotification: _onNotification,
                      child:
                          _isGrid ? _homeGridView(songs) : _homeListView(songs),
                      // Error:  Vertical viewport was given unbounded height.
                      // child: AnimatedCrossFade(
                      //   duration: Duration(milliseconds: 600),
                      //   firstChild: _homeGridView(songs),
                      //   secondChild: _homeListView(songs),
                      //   crossFadeState: widget.homeService.isGrid
                      //       ? CrossFadeState.showFirst
                      //       : CrossFadeState.showSecond,
                      // ),
                    ),
                    PlayingSongView(
                      playingSong: widget.songService.playingSong,
                      playerState: widget.songService.playerState,
                      currentTime: widget.songService.position,
                      position: animation,
                      pause: widget.songService.pause,
                      playLocal: widget.songService.playLocal,
                      slider: SongSlider(
                        value: widget.songService.position,
                        max: widget.songService.duration,
                        onChangeEnd: widget.songService.seek,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _SearchPage extends SearchDelegate<String> {
  Stream<List<Song>> songs;
  String select;
  var onTap;

  _SearchPage(this.songs, this.onTap);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.close),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  /// 用户从搜索页面提交搜索后显示的结果
  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<List<Song>>(
      stream: songs,
      initialData: List<Song>(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: Text('No Data!'),
          );
        }

        var filterSons =
            snapshot.data.where((Song s) => s.title.contains(query.trim()));
        return ListView(
          children: <Widget>[
            for (Song s in filterSons)
              ListTile(
                leading: Icon(
                  Icons.music_note,
                  color: Colors.red,
                ),
                title: Text(s.title),
                onTap: () {
                  onTap(s, snapshot.data.indexOf(s))();
                  close(context, null);
                },
              ),
          ],
        );
      },
    );
  }

  /// 当用户在搜索字段中键入查询时，在搜索页面正文中显示的建议
  @override
  Widget buildSuggestions(BuildContext context) {
    return StreamBuilder<List<Song>>(
      stream: songs,
      initialData: List<Song>(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: Text('No Data!'),
          );
        }

        var filterSons =
            snapshot.data.where((Song s) => s.title.contains(query.trim()));
        return ListView(
          children: <Widget>[
            for (Song s in filterSons)
              ListTile(
                leading: Icon(Icons.music_note),
                title: Text(s.title),
                onTap: () {
                  onTap(s, snapshot.data.indexOf(s))();
                  close(context, null);
                },
              ),
          ],
        );
      },
    );
  }
}
