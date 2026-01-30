# Complete Custom Theme for Discourse

A comprehensive Discourse theme that combines multiple features into one easy-to-install package.

## Features

### 1. Top Navigation Bar
- Black background with category icons
- Horizontal scrolling on mobile
- Shrinks to text-only when scrolling down
- Active category highlighting

### 2. Tag Navigation Bar
- Horizontal tag pills below the main nav
- Quick access to popular tags
- Responsive design

### 3. Topic Grid Layout
- 3-column card layout for topic lists
- Responsive: 2 columns on tablet/mobile
- Hover effects and shadows
- Clean, modern design

### 4. Sidebar Optimization
- Hides unnecessary sidebar sections
- Cleaner navigation experience

### 5. Floating Action Button (FAB)
- Quick access to create new topics
- Only visible for logged-in users
- Tooltip on hover
- Hidden on mobile

### 6. Activity Widget
- Shows events/announcements
- Image carousel with auto-rotation
- Fixed position on desktop

## Installation

### Via GitHub URL

1. Go to Admin → Customize → Themes
2. Click "Install" → "From a git repository"
3. Enter: `https://github.com/urizenk/discourse-complete-theme`
4. Click Install

### Via Theme Creator

1. Go to https://discourse.theme-creator.io/
2. Create new theme from Git repository
3. Enter the GitHub URL
4. Preview and test

## Configuration

The theme includes several settings you can customize:

- `show_floating_button` - Enable/disable FAB
- `show_activity_widget` - Enable/disable activity widget
- `nav_background_color` - Navigation bar background
- `nav_active_color` - Active item highlight color
- `grid_columns` - Number of columns (2, 3, or 4)

## Customization

### Modify Categories
Edit `common/head_tag.html` to change the categories shown in the top navigation.

### Modify Tags
Edit the tag navigation section in `common/head_tag.html`.

### Change Colors
Edit CSS variables in `common/common.scss`:

```scss
:root {
  --rtt-bg: #000000;        // Navigation background
  --rtt-text: #ffffff;       // Text color
  --rtt-active: #228B22;     // Active highlight
}
```

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## License

MIT License - Feel free to use and modify.

## Author

Custom Development
