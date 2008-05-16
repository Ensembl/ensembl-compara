package EnsEMBL::Web::Document::HTML::LocalContext;

### Generates the local context navigation menu, used in dynamic pages

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'tree' => undef, 'active' => undef, 'caption' => 'Local context' );
  return $self;
}

sub tree {
  ### a
  my $self = shift;
  $self->{tree} = shift if @_;
  return $self->{tree};
}

sub active {
  ### a
  my $self = shift;
  $self->{active} = shift if @_;
  return $self->{active};
}

sub caption {
  ### a
  my $self = shift;
  $self->{caption} = shift if @_;
  return $self->{caption};
}

sub render {
  my $self = shift;
  my $t = $self->tree;
  return unless $t;
  my $r = 0;
  my $previous_node;
  my $active = $self->active;
  my $active_node = $t->get_node( $active );
  my $active_l    = $active_node->left;
  my $active_r    = $active_node->right;
  my $counts = {};
  $self->printf( q(
      <dl id="local">
        <dt>%s</dt>), $self->caption );
  my $pad = '';
  foreach my $node ( $t->nodes ) {
    $r = $node->right if $node->right > $r;
    if( $previous_node && $node->left > $previous_node->right ) {
      foreach(1..($node->left - $previous_node->right-1)) {
        $self->print( "
$pad      </dl>
$pad    </dd>" );
        substr($pad,0,4)='';
      }
    }
    my $name = $node->data->{caption};
       #$name =~ s/\[\[counts::(\w+)\]\]/$counts->{$1}/eg;
       $name =~ s/\[\[counts::(\w+)\]\]/0/eg;
       $name = CGI::escapeHTML( $name );
    if( $node->data->{'url'} && $node->data->{'availability'} ) {
      $name = sprintf( '<a href="%s" title="%s">%s</a>', $node->data->{'url'}, $name, $name );
    }
    else {
      $name = sprintf('<span class="disabled" title="%s">%s</span>', $node->data->{'disabled'}, $name);
    }
    if( $node->is_leaf ) {
      $self->printf( qq(
$pad        <dd%s>%s</dd>), $node->key eq $active ? ' class="active"' :'', $name );
    } else {
      $self->printf( qq(
$pad        <dd class="%s">%s
$pad          <dl>), $node->left <= $active_l && $node->right >= $active_r ? 'open' : 'closed', $name );
      $pad .= '    ';
    }
    $previous_node = $node;
  }
  foreach(($previous_node->right+1)..$r) {
    $self->print( qq(
$pad      </dl>
$pad    </dd>) );
    substr($pad,0,4)='';
  }
  $self->print( q(
      </dl>) );
}

return 1;
