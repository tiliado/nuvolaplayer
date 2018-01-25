/*
 * Copyright 2015-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

namespace Nuvola {

public class AppCategoriesView : Gtk.TreeView
{
    private string? _category = null;
    private bool internal_category_change = false;
    public string? category
    {
        get {return _category;}
        set
        {
            if (value != _category)
            {
                _category = value;
                if (!internal_category_change)
                select_category(_category);
            }
        }
    }

    public AppCategoriesView(string? selected_category=null)
    {
        Object(headers_visible: false);
        var model = new Gtk.ListStore(2, typeof(string), typeof(string));
        var categories = Nuvola.get_desktop_categories();
        categories.for_each((key, name) =>
            {
                Gtk.TreeIter iter;
                // Audio and Video apps are is common category AudioVideo
                if (key != "Audio" && key != "Video")
                {
                    model.append(out iter);
                    model.set(iter, 0, key, 1, name);
                }
            });

        model.set_sort_column_id(1, Gtk.SortType.ASCENDING); // Sort by name
        model.set_sort_column_id(-2, Gtk.SortType.ASCENDING); // Disable sorting

        // Add "All" category as the first item (sorting must be disabled)
        Gtk.TreeIter iter;
        model.prepend(out iter);
        model.set(iter, 0, null, 1, _("All"));

        set_model(model);
        var text_cell = new Gtk.CellRendererText ();
        insert_column_with_attributes(-1, "Category", text_cell, "text", 1);

        var selection = get_selection();
        selection.mode = Gtk.SelectionMode.BROWSE;
        this.category = selected_category;
        if (selected_category == null)
        select_category(null);
        selection.changed.connect(on_selection_changed);
    }

    private void select_category(string? category)
    {
        internal_category_change = true;
        model.foreach((model, path, iter) =>
            {
                string? iter_category;
                model.get(iter, 0, out iter_category, -1);
                if (category == iter_category)
                {
                    get_selection().select_iter(iter);
                    return true;
                }
                return false;
            });
        internal_category_change = false;
    }

    private void on_selection_changed(Gtk.TreeSelection selection)
    {
        if (internal_category_change)
        return;
        Gtk.TreeModel model;
        Gtk.TreeIter iter;
        string? category = null;
        if (selection.get_selected(out model, out iter))
        model.get(iter, 0, &category, -1);

        if (this.category != category)
        {
            internal_category_change = true;
            this.category = (owned) category;
            internal_category_change = false;
        }
    }
}

} // namespace Nuvola
