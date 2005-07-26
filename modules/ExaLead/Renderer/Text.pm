package ExaLead::Renderer::Text;
use strict;

## packages used to grab content of XML
use ExaLead;
use Text::Wrap;

@ExaLead::TextRenderer::ISA = qw(ExaLead);

sub _render_group {
  my( $self, $group ) = @_;
  print $group->name,
        "\n";
}
sub _render_category {
  my( $self, $category, $level ) = @_;
  print "- "x($level+1),
        $category->name,
        ' [',
        $category->count,
        "]\n";
  foreach my $cat2 ( $category->children ) {
    $self->_render_category( $cat2, $level+1 );
  }
}

sub _render_hits_start { }
sub _render_hits_end {   }
sub _render_hit {
  my( $self,  $hit ) = @_;
  print $self->hack( $hit->field('title')->getHighlighted ),"\n"; 
  print '-' x 78,"\n";
  print wrap( '  ','  ',$self->hack($hit->field('description')->getHighlighted))."\n\n";
  print "Link: http://www.ensembl.org".$hit->URL,"\n\n";

  foreach my $hg ( $hit->groups ) {
    print $hg->name,": ";
    $self->_render_hitcats( $hg->children );
    print "\n";
  }
}

sub _render_hitcats {
  my( $self, @cats ) = @_;
  foreach my $cat ( @cats ) {
    print $cat->name,"; ";
    $self->_render_hitcats( $cat->children );
  }
}

sub hack {
  my($self, $T) = @_;
    $T =~ s/<br \/>/\n/g;
    $T =~ s/<span class="hi">/**/g;
    $T =~ s/<\/span>/**/g;
  return $T;
}

1;
