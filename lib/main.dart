import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HuazaiMusicBoxApp());
}

class HuazaiMusicBoxApp extends StatelessWidget {
  const HuazaiMusicBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '华仔音乐盒',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a5276),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String source;
  final int duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.source,
    required this.duration,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _results = [];
  bool _isLoading = false;
  String _status = '💡 输入关键词搜索音乐';
  String _currentSource = '全网搜索';
  Song? _currentSong;

  final List<String> _sources = ['全网搜索', '网易云', '酷狗', 'QQ音乐', '酷我', '咪咕'];
  final List<String> _hotTags = ['流行', '抖音', '情歌', '经典', '粤语', '民谣', '摇滚', '古风'];

  Future<List<Song>> _searchNetease(String keyword) async {
    try {
      final resp = await http.post(
        Uri.parse('https://music.163.com/api/search/get/web'),
        headers: {
          'Referer': 'https://music.163.com/',
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0',
        },
        body: 's=$keyword&type=1&limit=20&offset=0',
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final songs = data['result']?['songs'] as List? ?? [];
        return songs.map((s) => Song(
          id: s['id'].toString(),
          title: s['name'] ?? '',
          artist: (s['artists'] as List?)?.map((a) => a['name']).join(', ') ?? '',
          album: s['album']?['name'] ?? '',
          source: '网易云',
          duration: (s['duration'] ?? 0) ~/ 1000,
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Song>> _searchKugou(String keyword) async {
    try {
      final resp = await http.get(
        Uri.parse(
          'https://complexsearch.kugou.com/v2/search/song?keyword=${Uri.encodeComponent(keyword)}&page=1&pagesize=20&platform=WebFilter',
        ),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final songs = data['data']?['lists'] as List? ?? [];
        return songs.map((s) => Song(
          id: s['FileHash'] ?? '',
          title: s['SongName'] ?? '',
          artist: (s['SingerName'] ?? '').replaceAll('、', ', '),
          album: s['AlbumName'] ?? '',
          source: '酷狗',
          duration: s['Duration'] ?? 0,
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Song>> _searchQQ(String keyword) async {
    try {
      final resp = await http.get(
        Uri.parse(
          'https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=${Uri.encodeComponent(keyword)}&p=1&n=20&format=json&new_json=1',
        ),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final songs = data['data']?['song']?['list'] as List? ?? [];
        return songs.map((s) => Song(
          id: s['mid'] ?? '',
          title: s['name'] ?? '',
          artist: (s['singer'] as List?)?.map((a) => a['name']).join(', ') ?? '',
          album: s['album']?['name'] ?? '',
          source: 'QQ音乐',
          duration: s['interval'] ?? 0,
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _results = [];
      _status = '🔍 搜索中...';
    });

    List<Song> all = [];

    if (_currentSource == '全网搜索') {
      final futures = await Future.wait([
        _searchNetease(keyword),
        _searchKugou(keyword),
        _searchQQ(keyword),
      ]);
      for (var r in futures) all.addAll(r);
      all.shuffle();
    } else if (_currentSource == '网易云') {
      all = await _searchNetease(keyword);
    } else if (_currentSource == '酷狗') {
      all = await _searchKugou(keyword);
    } else if (_currentSource == 'QQ音乐') {
      all = await _searchQQ(keyword);
    } else {
      all = await _searchNetease(keyword);
    }

    setState(() {
      _results = all;
      _isLoading = false;
      _status = all.isEmpty ? '❌ 未找到相关歌曲' : '✅ 找到 ${all.length} 首歌曲';
    });
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Color _sourceColor(String source) {
    switch (source) {
      case '网易云': return const Color(0xFFc0392b);
      case '酷狗':  return const Color(0xFF2980b9);
      case 'QQ音乐': return const Color(0xFF27ae60);
      case '酷我':  return const Color(0xFF8e44ad);
      case '咪咕':  return const Color(0xFFe67e22);
      default:     return const Color(0xFF3498db);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a5276),
      body: SafeArea(
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: const [
                  Text('🎵 华仔音乐盒',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Text('多源搜索', style: TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),

            // 搜索区
            Container(
              color: const Color(0xFF2980b9),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 音乐源
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _sources.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          selected: _currentSource == s,
                          selectedColor: const Color(0xFF3498db),
                          labelStyle: TextStyle(
                            color: _currentSource == s ? Colors.white : Colors.white70,
                          ),
                          backgroundColor: const Color(0xFF1a5276),
                          onSelected: (_) => setState(() => _currentSource = s),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 搜索框
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、歌手...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF5dade2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => _doSearch(_searchController.text),
                      ),
                    ),
                    onSubmitted: _doSearch,
                  ),
                  const SizedBox(height: 8),

                  // 热门标签
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 4, top: 4),
                          child: Text('🔥', style: TextStyle(color: Colors.white70)),
                        ),
                        ..._hotTags.map((tag) => TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            _searchController.text = tag;
                            _doSearch(tag);
                          },
                          child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 状态栏
            Container(
              width: double.infinity,
              color: const Color(0xFF1a5276),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(_status, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),

            // 歌曲列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _results.isEmpty
                      ? const Center(
                          child: Text('搜索你喜欢的音乐 🎵',
                              style: TextStyle(color: Colors.white54, fontSize: 16)),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final song = _results[i];
                            final isPlaying = _currentSong?.id == song.id;
                            return Container(
                              color: i % 2 == 0
                                  ? const Color(0xFFebf5fb)
                                  : const Color(0xFFd4e6f1),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPlaying
                                      ? const Color(0xFF3498db)
                                      : const Color(0xFF1a5276),
                                  child: isPlaying
                                      ? const Icon(Icons.music_note, color: Colors.white, size: 16)
                                      : Text('${i + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1a5276),
                                    fontSize: 14,
                                    decoration: isPlaying ? TextDecoration.underline : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  song.artist,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _sourceColor(song.source),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        song.source,
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_fmt(song.duration),
                                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.play_circle,
                                        color: const Color(0xFF3498db), size: 28),
                                  ],
                                ),
                                onTap: () {
                                  setState(() => _currentSong = song);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('▶ ${song.title} - ${song.artist}'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF2980b9),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),

            // 底部播放器
            Container(
              height: 72,
              color: const Color(0xFF2980b9),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white54, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSong?.title ?? '未播放',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentSong != null
                              ? '${_currentSong!.artist} · ${_currentSong!.source}'
                              : '选择一首歌曲开始播放',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 44),
                    onPressed: () {
                      if (_currentSong == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请先选择一首歌曲')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
