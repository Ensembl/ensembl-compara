package ExaLead::Renderer;
use strict;

## packages used to grab content of XML
sub new {
  my( $class, $exalead ) = @_;
  my $self = {
    'exalead'   => $exalead,
  };
  bless $self, $class;
  return $self;
}

sub exalead   :lvalue { $_[0]->{'exalead'}; } # get/set string

## Renderers...

sub render_hits() {
  my $self = shift;
  return join '', map { $self->_render_hit( $_ ) } $self->exalead->hits;
}

sub render_spelling() {

}
sub render_navigation() {

}

sub render_summary() {
  my $self = shift;
  return $self->_render_text( "Enter the string you wish to search for in the box above." ) unless $self->exalead->query;
  if( $self->exalead->nmatches > $self->exalead->nhits ) {
    return $self->_render_text( "Your query matched @{[$self->exalead->nmatches]} entries in the search database. Viewing hits @{[$self->exalead->start+1]}-@{[$self->exalead->end+1]}" );
  } elsif( $self->exalead->nhits > 10 ) {
    return $self->_render_text( "Your query matched @{[$self->exalead->nmatches]} entries in the search database. Viewing hits @{[$self->exalead->start+1]}-@{[$self->exalead->end+1]}" );
  } elsif( $self->exalead->nhits > 0 ) {
    return $self->_render_text( "Your query matched @{[$self->exalead->nhits]} entries in the search database" );
  } else {
    return $self->_render_text( "Your query matched no entries in the search database" );
  }
}

sub render_form() {
  
}

sub render_tree {
  my $self = shift;
  my $out = '';
  foreach my $group ( sort { $a->name cmp $b->name } $self->exalead->groups ) {
    $out .= $self->_render_group( $group );
    foreach my $category ( sort { $a->name cmp $b->name } $group->children ) {
      $out .= $self->render_category( $category, 0 );
    }
  }
  return $out;
}

sub render_keywords {
  my $self = shift;
  my $out = '';
  return unless $self->exalead->keywords;
  foreach my $keyword ( sort { $a->name cmp $b->name } $self->exalead->keywords ) {
    $out.=$self->_render_category( $keyword, 0 );
  }
  return $out;
}

sub render_category {
  my( $self, $category, $level ) = @_;
  my $out = $self->_render_category( $category, $level );
  foreach my $cat2 ( sort { $a->name cmp $b->name } $category->children ) {
    $out .= $self->render_category( $cat2, $level+1 );
  }
  return $out;
}

1;
