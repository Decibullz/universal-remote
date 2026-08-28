enum TvFavorite {
  hulu('Hulu'),
  netflix('Netflix'),
  crunchyroll('Crunchyroll'),
  mlb('MLB');

  const TvFavorite(this.label);

  final String label;
}
