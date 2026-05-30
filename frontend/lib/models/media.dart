/// Data model representing a Movie, TV Show, or premium video listing in Cinegram.
/// Parsed either from TMDB (via our backend proxy) or from our custom Supabase tables.
class Media {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String mediaType; // 'movie' or 'tv'
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final List<int> genreIds;
  final List<String>? genres;
  final int? runtime;
  final String? trailerUrl;
  final String? streamUrl; // Premium stream link if unlocked/available

  Media({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.mediaType,
    this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.genreIds,
    this.genres,
    this.runtime,
    this.trailerUrl,
    this.streamUrl,
  });

  /// Factory constructor to parse Media objects from TMDB API JSON format.
  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as int,
      title: json['title'] ?? json['name'] ?? 'Untitled Media',
      overview: json['overview'] ?? 'No overview available.',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      mediaType: json['media_type'] ?? 'movie',
      releaseDate: json['release_date'] ?? json['first_air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      genres: json['genres'] != null
          ? List<String>.from((json['genres'] as List).map((g) => g['name'] ?? ''))
          : null,
      runtime: json['runtime'] as int?,
      trailerUrl: json['trailer_url'] as String?,
      streamUrl: json['stream_url'] as String?,
    );
  }

  /// Converts the Media object back to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'media_type': mediaType,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'genre_ids': genreIds,
      'genres': genres?.map((g) => {'name': g}).toList(),
      'runtime': runtime,
      'trailer_url': trailerUrl,
      'stream_url': streamUrl,
    };
  }

  /// Get the standard low/medium resolution TMDB poster URL.
  String get posterUrl {
    if (posterPath == null || posterPath!.isEmpty) {
      return 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=500'; // Modern backup image
    }
    if (posterPath!.startsWith('http')) return posterPath!;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  /// Get the standard high resolution TMDB poster URL.
  String get posterUrlOriginal {
    if (posterPath == null || posterPath!.isEmpty) {
      return 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?q=80&w=1080';
    }
    if (posterPath!.startsWith('http')) return posterPath!;
    return 'https://image.tmdb.org/t/p/original$posterPath';
  }

  /// Get the standard low/medium resolution TMDB backdrop URL.
  String get backdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) {
      return 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=1080'; // Modern backup image
    }
    if (backdropPath!.startsWith('http')) return backdropPath!;
    return 'https://image.tmdb.org/t/p/w780$backdropPath';
  }

  /// Get the high resolution TMDB backdrop URL.
  String get backdropUrlOriginal {
    if (backdropPath == null || backdropPath!.isEmpty) {
      return 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=1920';
    }
    if (backdropPath!.startsWith('http')) return backdropPath!;
    return 'https://image.tmdb.org/t/p/original$backdropPath';
  }

  /// Returns a clean formatted string of the year only.
  String get releaseYear {
    if (releaseDate == null || releaseDate!.isEmpty) return 'N/A';
    try {
      return releaseDate!.split('-')[0];
    } catch (_) {
      return 'N/A';
    }
  }

  /// Formatted vote average with single decimal place accuracy.
  String get ratingString => voteAverage.toStringAsFixed(1);

  /// High-fidelity premium mock data for previews and standalone rendering.
  static List<Media> get mockShowcaseList => [
        Media(
          id: 502356,
          title: "The Super Mario Bros. Movie",
          overview: "While working underground to fix a water main, Brooklyn plumbers—and brothers—Mario and Luigi are transported down a mysterious pipe and wander into a spin-tacular new world.",
          posterPath: "/qNBA25X2oCRV6OIp2JyQHM359S0.jpg",
          backdropPath: "/9n2mg6EOK1v41jQQUr55IL4yHYC.jpg",
          mediaType: "movie",
          releaseDate: "2023-04-05",
          voteAverage: 7.8,
          voteCount: 7600,
          genreIds: [16, 12, 10751, 14, 35],
          genres: ["Animation", "Adventure", "Family", "Fantasy", "Comedy"],
          runtime: 92,
          trailerUrl: "https://www.youtube.com/watch?v=TnGl01Fk9Vc",
        ),
        Media(
          id: 671,
          title: "Harry Potter and the Philosopher's Stone",
          overview: "Harry Potter has lived under the stairs at his aunt and uncle's house his whole life. But on his 11th birthday, he learns he's a powerful wizard and has been accepted to Hogwarts School of Witchcraft and Wizardry.",
          posterPath: "/wuMc08IPKLI7xtjB5n9R7jf4N5F.jpg",
          backdropPath: "/hziiv142w7u4gGa6fs1tcBs34Zq.jpg",
          mediaType: "movie",
          releaseDate: "2001-11-16",
          voteAverage: 7.9,
          voteCount: 26000,
          genreIds: [12, 14, 10751],
          genres: ["Adventure", "Fantasy", "Family"],
          runtime: 152,
          trailerUrl: "https://www.youtube.com/watch?v=VyHV0BRZmTs",
        ),
        Media(
          id: 155,
          title: "The Dark Knight",
          overview: "Batman raises the stakes in his war on crime. With the help of Lt. Jim Gordon and District Attorney Harvey Dent, Batman sets out to dismantle the remaining criminal organizations that plague the streets.",
          posterPath: "/qJ2tWMB22UNXRclQmc9QG3a1zW7.jpg",
          backdropPath: "/oXGN685hFrC9m6t12fyQH2G34eg.jpg",
          mediaType: "movie",
          releaseDate: "2008-07-16",
          voteAverage: 8.5,
          voteCount: 31000,
          genreIds: [18, 28, 80, 53],
          genres: ["Drama", "Action", "Crime", "Thriller"],
          runtime: 152,
          trailerUrl: "https://www.youtube.com/watch?v=EXeTwQWrcwY",
        ),
        Media(
          id: 1396,
          title: "Breaking Bad",
          overview: "Walter White, a New Mexico chemistry teacher, diagnosed with Stage III cancer, turns to a life of crime, partnering with his former student Jesse Pinkman to produce and sell methamphetamine.",
          posterPath: "/ztkUQjB1616v2n7kyUTu3s2A6ry.jpg",
          backdropPath: "/9faXYmN40EXmJg0v57v9YnZz25Z.jpg",
          mediaType: "tv",
          releaseDate: "2008-01-20",
          voteAverage: 8.9,
          voteCount: 13500,
          genreIds: [18, 80],
          genres: ["Drama", "Crime"],
          runtime: 49,
          trailerUrl: "https://www.youtube.com/watch?v=HhesaQXLuRY",
        ),
      ];
}
