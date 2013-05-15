use Test::More;
BEGIN {
  plan skip_all => <<'END_HELP' unless $ENV{MOO_TEST_MD};
This test will not run unless you set MOO_TEST_MD to a true value.

  Valid values are:

     all                  Test every dist which depends on Moose except those
                          that we know cannot be tested. This is a lot of
                          distros (hundreds).

     Dist::1,Dist::2,...  Test the individual dists listed.

     MooX                 Test all Moo extension distros.

     1                    Run the default tests. We pick 200 random dists and
                          test them.
END_HELP
}

use Test::DependentModules qw( test_module );
use MetaCPAN::API;
use List::Util ();

# avoid any modules that depend on these
my @bad_prereqs = qw(Gtk2 Padre Wx);

my $mcpan = MetaCPAN::API->new;
my $res = $mcpan->post(
  '/search/reverse_dependencies/Moo' => {
    query => {
      filtered => {
        query => { "match_all" => {} },
        filter => {
          and => [
            { term => { 'release.status' => 'latest' } },
            { term => { 'release.authorized' => \1 } },
            { not => { filter => {
              or => [
                map { { term => { 'dependency.module' => $_ } } } @bad_prereqs,
              ],
            } } }
          ],
        },
      },
    },
    size => 5000,
    fields => ['distribution', 'provides', 'metadata.provides'],
  },
);

my %bad_dist;
my $sec_reason;
my %skip;
my %todo;

my $hash;
for my $line (<DATA>) {
  chomp $line;
  next unless $line =~ /\S/;
  if ( $line =~ /^#\s*(\w+)(?::\s*(.*?)\s*)?$/ ) {
    die "Invalid action in DATA section ($1)"
      unless $1 eq 'SKIP' || $1 eq 'TODO';
    $hash = $1 eq 'SKIP' ? \%skip : \%todo;
    $sec_reason = $2;
  }

  my ( $dist, $reason ) = $line =~ /^(\S*)\s*(?:#\s*(.*?)\s*)?$/;
  next unless defined $dist && length $dist;

  $hash->{$dist} = $reason || $sec_reason;
}

my %todo_module;
my @modules;
for my $hit (@{ $res->{hits}{hits} }) {
  my $dist = $hit->{fields}{distribution};
  next
    if exists $skip{$dist};
  next
    if $dist =~ /^(?:Task|Bundle|Acme)-/;

  my $module = (sort { length $a <=> length $b || $a cmp $b } do {
    if (my $provides = $hit->{fields}{provides}) {
      ref $provides ? @$provides : ($provides);
    }
    elsif (my $provides = $hit->{fields}{'metadata.provides'}) {
      keys %$provides;
    }
    else {
      (my $module = $dist) =~ s/-/::/g;
      ($module);
    }
  })[0];
  $todo_module{$module} = $todo{$dist}
    if exists $todo{$dist};
  push @modules, $module;
  $module;
}
@modules = sort @modules;

if ( $ENV{MOO_TEST_MD} eq 'MooX' ) {
  @modules = grep /^MooX(?:$|::)/, @modules;
}
elsif ( $ENV{MOO_TEST_MD} eq '1' ) {
  diag(<<'EOF');
  Picking 200 random dependents to test. Set MOO_TEST_MD=all to test all
  dependents or MOO_TEST_MD=MooX to test extension modules only.
EOF
  @modules = (List::Util::shuffle(@modules))[0..199];
}
elsif ( $ENV{MOO_TEST_MD} ne 'all' ) {
  my @chosen = split /,/, $ENV{MOO_TEST_MD};
  my %modules = map { $_ => 1 } @modules;
  if (my @unknown = grep { !$modules{$_} } @chosen) {
    die "Unknown modules: @unknown";
  }
  @modules = @chosen;
}

if (grep { $_ eq '--show' } @ARGV) {
  print "Dependents:\n";
  print "  $_\n" for @modules;
  exit;
}

plan tests => scalar @modules;
for my $module (@modules) {
  local $TODO = $todo_module{$module} || '???'
    if exists $todo_module{$module};
  test_module($module);
}


__DATA__

# SKIP: no tests
CPAN-Mirror-Finder
Catmandu-AlephX
Device-Hue
Novel-Robot
Novel-Robot-Browser
Novel-Robot-Parser
Thrift-API-HiveClient
Tiezi-Robot-Parser

# SKIP: broken
App-Presto
Catmandu-Store-Lucy
Dancer2-Session-Sereal
Data-Localize
HTML-Zoom-Parser-HH5P
Message-Passing-ZeroMQ
Tak

# SKIP: broken tests
Template-Flute
Uninets-Check-Modules-HTTP
Uninets-Check-Modules-MongoDB
Uninets-Check-Modules-Redis

# SKIP: missing prereqs
Catmandu-Z3950
Tiezi-Robot

# SKIP: bad prereq version listed
Dancer2-Session-Cookie
Dancer2-Session-JSON

# TODO: broken, pending release
Hg-Lib
P9Y-ProcessTable
GeoIP2

# SKIP: OS specific
Linux-AtaSmart

# TODO: broken by Moo change
Math-Rational-Approx        # RT#84035
App-Services                # RT#85255
