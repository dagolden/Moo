package InlineModule;
use Moo::_strictures;

BEGIN {
  *_HAS_PERLIO = "$]" >= 5.008_000 ? sub(){1} : sub(){0};
}

sub import {
  my ($class, %modules) = @_;
  unshift @INC, inc_hook(%modules);
}

sub inc_hook {
  my (%modules) = @_;
  my %files = map {
    (my $file = "$_.pm") =~ s{::}{/}g;
    $file => $modules{$_};
  } keys %modules;

  sub {
    return
      unless exists $files{$_[1]};
    my $module = $files{$_[1]};
    if (!defined $module) {
      die "Can't locate $_[1] in \@INC (hidden) (\@INC contains: @INC).\n";
    }
    inc_module($module);
  }
}

sub inc_module {
  my $code = $_[0];
  if (_HAS_PERLIO) {
    open my $fh, '<', \$code
      or die "error loading module: $!";
    return $fh;
  }
  else {
    return sub {
      return 0 unless length $code;
      $code =~ s/^([^\n]*\n?)//;
      $_ = $1;
      return 1;
    };
  }
}

1;
