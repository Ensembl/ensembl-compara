# $Id$

package EnsEMBL::Web::Document::Panel::Summary;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub add_description {
  my ($self, $description) = @_;
  return "<p>$description</p>";
}

sub add_row {
  my ($self, $label, $content) = @_;
  
  return qq{
    <dl class="summary">
      <dt>$label</dt>
      <dd>
        $content
      </dd>
    </dl>
  };
}

1;
