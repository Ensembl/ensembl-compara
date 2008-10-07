package XHTML::Validator;

use strict;
use warnings;
no warnings 'uninitialized';

### HTML validator class
###
### Used to validate a subset of XHTML to make sure that code is both DOM safe and clear of any issues
### with respect to inserting script tags etc.
###
### Usage: my $valid = new XHTML::Validator( 'set' ); my $error = $valid->validator( $string );
###
### Returns an error message indicating the first error found
###
### 'set' can currently be one of "no-tags" - just checks for valid entities and that there are no tags; 
### "in-line" - only allows in-line elements; "normal" - allows selection of block level tags

our $sets = {};

### Package global variable $sets defines the different groups of tags allowed

$sets->{'no-tags'} = {
  'ent' => '&(amp|lt|gt|quot|apos);',
  'ats' => {},
  'nts' => {}
};

$sets->{'in-line'} = {
  'ent' => $sets->{'no-tags'}{'ent'},
  'ats' => { map {($_,1)} qw(class title id style) },
  'nts' => {
    'img'    => { 'rt' => 1, 'tx' => 0, 'at' => {map {($_,1)} qw(src alt title)}, 'tg' => {} },
    'a'      => { 'rt' => 1, 'tx' => 1, 'at' => {map {($_,1)} qw(href name rel)}, 'tg' => {map {($_,1)} qw(img span em strong)} },
    'strong' => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em)       } },
    'em'     => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a    strong)} },
    'span'   => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong)} }
  }
};
$sets->{'normal'} = {
  'ent' => $sets->{'no-tags'}{'ent'},
  'ats' => $sets->{'in-line'}{'ats'},
  'nts' => {
    %{ $sets->{'in-line'}{'nts'} },
    'p'  => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong)           } },
    'li' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'dt' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'dd' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'ol' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(li)   } },
    'ul' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(li)   } },
    'dl' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(dd dt)} },
  }
};

sub new {
  my $class = shift;
  my $self = { 'set' => shift || 'normal' };
  bless $self, $class;
  return $self;
}

sub info {
  my( $self, $k ) = @_;
  return $sets->{ $self->{'set'} }{$k};
}

sub trim {
  my( $self, $string ) = @_;
  $string =~ s/\s+/ /g;
  $string =~ s/^\s//g;
  $string =~ s/\s$//g;
  return $string;
}

sub validate {
  my( $self, $string ) = @_;
## Tokenize string;
  my @a = ();
  foreach my $w ( split /(?=<)/, $string ) {
    if( $w =~/^</ ) {
      my ($x,$y) = $w =~ /^([^>]+>)([^>]*)$/;
      if( $x ) {
        push @a, $x;
        push @a, $y if $y =~ /\S/;
      } else {
        return 'Not well formed: "'.$self->trim($w).'"';
      }
    } elsif( $w =~ />/ ) {
      return 'Not well formed: "'.$self->trim($w).'"';
    } else {
      push @a, $w;
    }
  }
  my @stk = ();
  my $ent_regexp = $self->info('ent');
  foreach my $w ( @a ) {
    my $LN = $stk[0];
    if( $w =~ /^</ ) {
      if( $w =~/<\/(\w+)>/ ) { # We have a close tag...
        if( @stk ){
          my $LAST = shift @stk;
          return qq(Mismatched tag "/$1" != "$LAST") if $LAST ne $1;
	} else {
          return qq(Attempt to close too many tags "/$1");
	}
      } elsif( $w =~ /<(\w+)(.*?)(\/?)>/ ) { ## tag node
        my $TN  = $1;
        my $ATS = $2;
        my $SCL = $3 eq '/' ? 1 : 0;
        return qq(Non lower-case tag: "$TN") if $TN=~/[A-Z]/;
        return qq(Tag "$TN" not allowed)              unless $self->info('nts')->{$TN};
        return qq(Tag "$TN" not allowed in "$LN")     if  $LN && !$self->info('nts')->{$LN}{'tg'}{$TN};
        return qq(Tag "$TN" not allowed at top level) if !$LN && !$self->info('nts')->{$TN}{'rt'};
        unshift @stk, $TN unless $SCL;
        next unless $ATS;
        while( $ATS =~ s/^\s+(\w+)\s*=\s*"([^"]*)"// ) {
          my $AN = $1;
          my $vl = $2;
          return qq(Non lower case attr name "$AN" in tag "$TN") if $AN =~ /[A-Z]/;
          return qq(Attr "$AN" not valid in tag "$TN")           unless $self->info('ats')->{$AN} || $self->info('nts')->{$TN}{'at'}{$AN};
          foreach my $e ( split /(?=&)/, $vl ) {
            return qq(Unknown entity ").$self->trim($e).qq(" in attr "$AN" in tag"$TN") if substr($e,0,1)eq'&' && $e !~ /$ent_regexp/;
          }
        }
        return qq(Problem with tag "$TN"'s attrs ($ATS).) if $ATS=~/\S/;
      } else {
	return qq(Malformed tag "$w");
      }
    } else { ## text nodfe
      return qq(No raw text allowed in "LN") if $LN && !$self->info('nts')->{$LN}{'rt'};
      foreach my $e ( split /(?=&)/, $w ) {
        return qq(Unknown entity ").$self->trim($e).qq(") if substr($e,0,1)eq'&' && $e !~ /$ent_regexp/;
      }
    }
  }
  return @stk ? qq(Unclosed tags "@stk") : undef;
}

1;
