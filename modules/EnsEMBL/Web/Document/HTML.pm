package EnsEMBL::Web::Document::HTML;

use strict;
use base qw(EnsEMBL::Web::Root);
use EnsEMBL::Web::RegObj;

sub new {
  my $class = shift;
  my $self = { 
    '_renderer' => undef, 
    '_home_url' => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT || '/',
    '_img_url'  => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_IMAGE_ROOT || '/i/',
    @_ };
  bless $self, $class;
  return $self;
}


sub renderer :lvalue { return $_[0]->{_renderer}; }
sub home_url :lvalue { return $_[0]->{'_home_url'}; }
sub img_url  :lvalue { return $_[0]->{'_img_url'}; }

sub printf { my $self = shift; $self->renderer->printf( @_ ) if $self->{'_renderer'}; }
sub print { my $self = shift; $self->renderer->print( @_ )   if $self->{'_renderer'}; }

sub render_webtree {
  my ($self, $node, $level, $max_level) = @_;
  my $html = '';
  $level = 0 unless $level;

  my $section_url   = $node->{_path};
  my $section_title = $node->{_title};
  my ($title, $class);

  my @sortable;
  foreach my $subsection (keys %$node) {
    push (@sortable, $subsection) if ref($node->{$subsection}) eq 'HASH';
  }

  my @order = sort {
        $node->{$a}{_order} <=> $node->{$b}{_order}
        || $node->{$a}{_title} cmp $node->{$b}{_title}
        || $node->{$a} cmp $node->{$b}
      }
      @sortable;

  foreach my $section (@order) {
    next if $section =~ /^_/;
    $class = '';
    my $subsection = $node->{$section};
    next unless keys %$subsection;
    $title = $subsection->{'_title'} || ucfirst($section);
    #if ($location eq $subsection->{'_path'}) {
    #  $class = ' class="active"';
    #}
    if ($subsection->{'_nolink'}) {
      $html .= qq(<dd class="open"><strong>$title</strong>);
    }
    else {
      $html .= sprintf(qq(<dd class="open"><strong><a href="%s"%s>%s</a></strong>),
        $subsection->{'_path'}, $class, $title
      );
    }
    
    #unless ($level == $max_level) {
    #  for (sort { $node->{$a} cmp $node->{$b} } @dirs) {
    #    $html .= $self->write_web_tree($node->{$_}, $level + 1, $max_level);
    #  }
    #}
  }
  return $html;

}

1;
