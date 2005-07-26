package ExaLead;
use strict;

## packages used to grab content of XML
use XML::Simple;
use LWP;
use CGI;

use ExaLead::SpellingSuggestion;
use ExaLead::Keyword;
use ExaLead::Query;
use ExaLead::QueryParameter;
use ExaLead::QueryTerm;
use ExaLead::TextSeg;
use ExaLead::Value;
use ExaLead::Group;
use ExaLead::Category;
use ExaLead::Link;
use ExaLead::Hit;
use ExaLead::HitGroup;
use ExaLead::HitCategory;

sub new {
  my( $class ) = @_;
  my $self = {
    'engineURL'  => '',
    'rootURL'    => '',
    'nmatches'  => 0,
    'nhits'     => 0,
    'start'     => 0,
    'end'       => 0,
    'last'      => 0,
    'estimated' => 0,
    'keywords'  => [],
    'spellings' => [],
    'groups' => [],
    'hits'   => [],
    'query_string' => '',
    'hidden_fields' => []
  };
  bless $self, $class;
  return $self;
}

sub engineURL :lvalue { $_[0]->{'engineURL'}; } # get/set string
sub rootURL   :lvalue { $_[0]->{'rootURL'}; } # get/set string
sub nmatches  :lvalue { $_[0]->{'nmatches'};  } # get/set int
sub nhits     :lvalue { $_[0]->{'nhits'};     } # get/set int
sub start     :lvalue { $_[0]->{'start'};     } # get/set int
sub end       :lvalue { $_[0]->{'end'};       } # get/set int
sub last      :lvalue { $_[0]->{'last'};      } # get/set int
sub estimated :lvalue { $_[0]->{'estimated'}; } # get/set int

sub query :lvalue { $_[0]->{'query'}; } # get/set Query object

sub addGroup  { push @{$_[0]{'groups'}}, $_[1]; }
sub addSpellingSuggestion  { push @{$_[0]{'spellings'}}, $_[1]; }
sub addKeyword  { push @{$_[0]{'keywords'}}, $_[1]; }
sub addHit      { push @{$_[0]{'hits'}},   $_[1]; }

sub spellingsuggestions { return @{$_[0]{'spellings'}};         }
sub keywords { return @{$_[0]{'keywords'}};         }
sub groups { return @{$_[0]{'groups'}};         }
sub hits   { return @{$_[0]{'hits'}};           }

## Parser and associated functions...

sub parse {
  my( $self, $q ) = @_;
  my $search_URL = $self->engineURL.'?_f=xml2';
  foreach my $VAR ( $q->param() ) {
    $search_URL .= join '', map { "&$VAR=".CGI::escape($_) } $q->param( $VAR );
  }
  warn $search_URL;
  my $ua = LWP::UserAgent->new();
  my $res = $ua->get( $search_URL );
  $self->_parse( $res->content );
}

sub _parse {
  my( $self, $XML ) = @_;
## Convert XML to object hash....
  my $xml = XMLin( $XML, ForceArray=>1, KeyAttr=>[] );
  $self->{'XML'} = $xml;

## Parse Query....
  my $Q = $xml->{'Query'}[0];
  my $query = new ExaLead::Query( $Q->{'query'}, $Q->{'context'} );
  foreach my $qt_xml ( @{$Q->{'QueryTerm'}} ) {
    $query->addTerm( new ExaLead::QueryTerm( $qt_xml->{'regexp'}, $qt_xml->{'level'} ) );
  }
  foreach my $qp_xml ( @{$Q->{'QueryParameter'}} ) {
    $query->addParameter( new ExaLead::QueryParameter( $qp_xml->{'name'}, $qp_xml->{'value'} ) );
  }
  $self->query = $query;
  
## Parse Groups....
  foreach my $T ( @{$xml->{'Groups'}[0]{'Group'}||[]} ) {
    my $group = new ExaLead::Group( $T->{'title'}, $T->{'count'} );
    $group->link( 'reset' ) = new ExaLead::Link( $T->{'resetHref'}, $self ) if exists $T->{'resetHref'};
    $group->addChildren( $self->_parse_category_tree( $T->{'Category'} ) );
    $self->addGroup( $group );
  }

## Parse Hits....
  $self->nmatches  = $xml->{'Hits'}[0]{'nmatches'};
  $self->nhits     = $xml->{'Hits'}[0]{'nhits'};
  $self->start     = $xml->{'Hits'}[0]{'start'};
  $self->end       = $xml->{'Hits'}[0]{'end'};
  $self->estimated = $xml->{'Hits'}[0]{'estimated'};
  $self->last      = $xml->{'Hits'}[0]{'last'};
  foreach my $hit_xml ( @{$xml->{'Hits'}[0]{'Hit'}||[]} ) {
    my $hit = new ExaLead::Hit( $hit_xml->{'url'}, $hit_xml->{'score'} );
    foreach my $hit_field_xml ( @{$hit_xml->{'HitField'}||[]} ) {
      my $name = $hit_field_xml->{'name'};
      if( exists($hit_field_xml->{'TextSeg'} ) ) {
        my $TS = new ExaLead::TextSeg();
        foreach my $ts_xml ( @{$hit_field_xml->{'TextSeg'}} ) {
          $TS->addPart($ts_xml->{'content'}||' ', $ts_xml->{'highlighted'});
        }
        $hit->addField( $name, $TS );
      } elsif( exists($hit_field_xml->{'value'} ) ) {
        my $TS = new ExaLead::Value( $hit_field_xml->{'value'}, $query );
        $hit->addField( $name, $TS );
      }
    } 
    foreach my $hit_group_xml( @{$hit_xml->{'HitGroup'}||[]} ) {
      my $hitgroup = new ExaLead::HitGroup( $hit_group_xml->{'title'} );
      $hitgroup->addChildren( $self->_parse_hit_category_tree( $hit_group_xml->{'HitCategory'} ) );
      $hit->addGroup( $hitgroup );
    }
    $self->addHit( $hit );
  }
## Parse spelling suggestions....
  foreach my $spelling_xml ( @{$xml->{'SpellingSuggestions'}[0]{'SpellingSuggestion'}||[]} ) {
    foreach my $T ( @{$spelling_xml->{'SpellingSuggestionVariant'}||[]} ) {
      $self->addSpellingSuggestion( new ExaLead::SpellingSuggestion( 
        $T->{'query'}, $T->{'display'}
      ));
    }
  }
## Parse relevant keywords....
  foreach my $k_xml ( @{$xml->{'Keywords'}[0]{'Keyword'}||[]} ) {
    my $K = new ExaLead::Keyword( $k_xml->{'display'}, $k_xml->{'count'} );
    my @links = qw( exclude reset refine );
    foreach my $n ( @links ) {
      $K->link( $n ) = new ExaLead::Link( $k_xml->{ $n."Href" }, $self ) if exists( $k_xml->{$n."Href"} );
    }
    $self->addKeyword( $K );
  }
}

sub _parse_category_tree {
  my( $self, $category ) = @_;
  my @links = qw( exclude reset refine );
  my $cat_array = [];
  foreach my $cat (@$category) {
    my $entry = new ExaLead::Category( $cat->{'name'}, $cat->{'count'}, $cat->{'gcount'} );
    foreach my $n ( @links ) {
      $entry->link( $n ) = new ExaLead::Link( $cat->{ $n."Href" }, $self ) if exists( $cat->{$n."Href"} );
    }
    $entry->addChildren( $self->_parse_category_tree( $cat->{'Category'} ) ) if exists $cat->{'Category'};
    push @$cat_array, $entry;
  }
  return $cat_array;
}

sub _parse_hit_category_tree {
  my( $self, $category ) = @_;
  my $cat_array = [];
  foreach my $cat (@$category) {
    my $entry = new ExaLead::HitCategory( $cat->{'name'} );
    $entry->link( 'browse' ) = new ExaLead::Link( $cat->{ "browseHref" }, $self ) if exists $cat->{"browseHref"};
    $entry->addChildren( $self->_parse_hit_category_tree( $cat->{'HitCategory'} ) ) if exists $cat->{'HitCategory'};
    push @$cat_array, $entry;
  }
  return $cat_array;
}

1;
