class CastMember {
  final String name;
  final String role;
  final String imageUrl;

  const CastMember({
    required this.name,
    required this.role,
    required this.imageUrl,
  });
}

class MediaItem {
  final String id;
  final String title;
  final String type; // 'Movie' | 'TV Show' | 'Anime'
  final String backdropUrl;
  final String posterUrl;
  final double rating;
  final String year;
  final String duration;
  final String synopsis;
  final List<String> genres;
  final List<CastMember> cast;
  final double? progress; // For Continue Watching row
  final String category; // 'Trending' | 'Popular' | 'Top Rated'

  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.backdropUrl,
    required this.posterUrl,
    required this.rating,
    required this.year,
    required this.duration,
    required this.synopsis,
    required this.genres,
    required this.cast,
    this.progress,
    required this.category,
  });
}

// Global premium static database
final List<MediaItem> mockMediaDatabase = [
  const MediaItem(
    id: 'm1',
    title: 'Aetherius: Echoes of Eternity',
    type: 'Movie',
    backdropUrl: 'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=500',
    rating: 9.6,
    year: '2026',
    duration: '2h 42m',
    category: 'Trending',
    synopsis: 'In the twilight of human civilization, a stellar cartographer discovers a high-frequency rhythmic pulse coming from the center of a dormant supermassive black hole. As he embarks on a journey beyond the event horizon, he unravels a cosmic design that binds human memory, gravitational anomalies, and the rebirth of stars.',
    genres: ['Sci-Fi', 'Mystery', 'Drama'],
    progress: 0.74,
    cast: [
      CastMember(
        name: 'Christian Bale',
        role: 'Commander Ethan Vance',
        imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150',
      ),
      CastMember(
        name: 'Jessica Chastain',
        role: 'Dr. Clara Reyes',
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
      ),
      CastMember(
        name: 'Timothée Chalamet',
        role: 'Leo Vance',
        imageUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=150',
      ),
      CastMember(
        name: 'Zendaya Coleman',
        role: 'AI System V.E.R.A.',
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 'm2',
    title: 'Shadow Protocol: Tokyo Neon',
    type: 'Movie',
    backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=500',
    rating: 8.9,
    year: '2025',
    duration: '2h 18m',
    category: 'Trending',
    synopsis: 'Deep within the rain-slicked, neon-drenched alleyways of near-future Tokyo, an elite cybersecurity operative code-named "Spectre" is framed for the assassination of a high-ranking corporate minister. Armed with tactical holographic stealth gear, Spectre must navigate an underworld of augment-enhanced syndicates and rogue synthetic intelligence to expose a conspiracy that threatens the world’s neural grid.',
    genres: ['Action', 'Thriller', 'Cyberpunk'],
    progress: 0.35,
    cast: [
      CastMember(
        name: 'Ken Watanabe',
        role: 'Director Ishikawa',
        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
      ),
      CastMember(
        name: 'Scarlett Johansson',
        role: 'Spectre / Kusanagi',
        imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=150',
      ),
      CastMember(
        name: 'Hiroyuki Sanada',
        role: 'Saito Ozu',
        imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 't1',
    title: 'Severance: The Deep Grid',
    type: 'TV Show',
    backdropUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?q=80&w=500',
    rating: 9.4,
    year: '2025',
    duration: 'Season 2 • 10 Episodes',
    category: 'Popular',
    synopsis: 'Following the dramatic breakthrough of the Lumon inner-office escape, the severed employees are placed under secondary, highly experimental neural compartmentalization protocols. In this claustrophobic psychological thriller, the lines between personal trauma, corporate supremacy, and objective reality blur until the employees begin communicating with their outies via subtle auditory feedback loops.',
    genres: ['Sci-Fi', 'Psychological', 'Drama'],
    progress: 0.91,
    cast: [
      CastMember(
        name: 'Adam Scott',
        role: 'Mark Scout',
        imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150',
      ),
      CastMember(
        name: 'Patricia Arquette',
        role: 'Harmon Cobel',
        imageUrl: 'https://images.unsplash.com/photo-1558203728-00f45181dd84?q=80&w=150',
      ),
      CastMember(
        name: 'John Turturro',
        role: 'Irving Bailiff',
        imageUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 'a1',
    title: 'Cyberpunk: Phantom Protocol',
    type: 'Anime',
    backdropUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=500',
    rating: 9.3,
    year: '2026',
    duration: '12 Episodes',
    category: 'Trending',
    synopsis: 'Set in the chaotic, high-octane sprawl of Night City, a brilliant young netrunner discovers a dormant cyber-virus of military-grade proportions. Targeted by Arasaka\'s most ruthless cyber-ninja strike teams, she teams up with a hot-blooded mercenary whose body is already half-consumed by an experimental kinetic exoskeleton to pull off the ultimate digital heist.',
    genres: ['Anime', 'Action', 'Sci-Fi'],
    progress: 0.55,
    cast: [
      CastMember(
        name: 'Aoi Yuki',
        role: 'Luna (Netrunner)',
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
      ),
      CastMember(
        name: 'Mamoru Miyano',
        role: 'Kaelen (Mercenary)',
        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 'm3',
    title: 'The Alchemist\'s Horizon',
    type: 'Movie',
    backdropUrl: 'https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=500',
    rating: 8.7,
    year: '2024',
    duration: '2h 5m',
    category: 'Top Rated',
    synopsis: 'In an alternate 19th-century Europe powered by steam and esoteric chemical reactions, a reclusive female alchemist attempts to unlock the formula for absolute rejuvenation. When her research is hijacked by an imperial military faction seeking to create immortal soldiers, she runs off into the Swiss Alps to protect the secret of life itself.',
    genres: ['Fantasy', 'Adventure', 'Drama'],
    progress: 0.12,
    cast: [
      CastMember(
        name: 'Florence Pugh',
        role: 'Helena Thorne',
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150',
      ),
      CastMember(
        name: 'Michael Fassbender',
        role: 'Major Sterling',
        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 't2',
    title: 'Succession: Legacy of Sand',
    type: 'TV Show',
    backdropUrl: 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?q=80&w=500',
    rating: 9.1,
    year: '2024',
    duration: '10 Episodes',
    category: 'Popular',
    synopsis: 'In the hyper-competitive world of international clean-energy monopolies, a ruthless family patriarch pits his four ambitious children against one another for supreme control of the global silicon reserves. Filmed in stunning high-contrast minimalist locations around Norway and the UAE, this intense boardroom thriller displays family dysfunction at its absolute peak.',
    genres: ['Drama', 'Corporate', 'Thriller'],
    cast: [
      CastMember(
        name: 'Brian Cox',
        role: 'Arthur Sterling',
        imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=150',
      ),
      CastMember(
        name: 'Jeremy Strong',
        role: 'Kendall Sterling',
        imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150',
      ),
    ],
  ),
  const MediaItem(
    id: 'a2',
    title: 'Chronicles of the Void',
    type: 'Anime',
    backdropUrl: 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?q=80&w=1200',
    posterUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=500',
    rating: 8.8,
    year: '2025',
    duration: '24 Episodes',
    category: 'Top Rated',
    synopsis: 'When a mysterious dimensional crack opens in orbit above Kyoto, gravity begins to fluctuate unpredictably. A high school physics prodigy and a quiet, ancient warrior who emerged from the tear must work together to close the gate before the absolute cold of the cosmic void consumes Japan.',
    genres: ['Anime', 'Sci-Fi', 'Fantasy'],
    cast: [
      CastMember(
        name: 'Hiroshi Kamiya',
        role: 'Ren (Void Warrior)',
        imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150',
      ),
      CastMember(
        name: 'Kana Hanazawa',
        role: 'Yuki (Prodigy)',
        imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=150',
      ),
    ],
  ),
];
