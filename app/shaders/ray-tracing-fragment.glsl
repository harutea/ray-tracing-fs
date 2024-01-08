uniform vec2 u_resolution;
uniform float u_time;

struct Ray {
  vec3 origin;
  vec3 direction;
};

vec3 ray_at(Ray ray, float t) {
  return ray.origin + t*ray.direction;
}

bool ray_sphere_intersection(Ray ray, vec3 center, float radius) {
  vec3 co = ray.origin - center;
  float a = dot(ray.direction, ray.direction);
  float b = 2.0 * dot(co, ray.direction);
  float c = dot(co, co) - radius*radius;
  float discriminant = b*b - 4.0*a*c;
  return (discriminant >= 0.0);
}

vec3 ray_color(Ray ray) {
  if (ray_sphere_intersection(ray, vec3(0, 0, -1), 0.5))
    return vec3(1.0, 0.0, 0.0);

  vec3 unit_direction = normalize(ray.direction);
  float a = 0.5*(unit_direction.y + 1.0);
  return (1.0-a)*vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.7, 1.0);
}


void main() {
  float aspect_ratio = 16.0 / 9.0;

  // camera
  float focal_length = 1.0;
  float viewport_height = 2.0;
  float viewport_width = viewport_height / (u_resolution.y/u_resolution.x);
  vec3 camera_center = vec3(0, 0, 0);

  vec3 viewport_u = vec3(viewport_width, 0, 0);
  vec3 viewport_v = vec3(0, viewport_height, 0);

  vec3 pixel_delta_u = viewport_u / u_resolution.x;
  vec3 pixel_delta_v = viewport_v / u_resolution.y;

  vec3 viewport_upper_left = camera_center - vec3(0, 0, focal_length) - viewport_u/2.0 - viewport_v/2.0;
  vec3 pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

  // vec2 st = gl_FragCoord.xy / u_resolution.xy;

  vec3 pixel_center = pixel00_loc + (gl_FragCoord.x * pixel_delta_u) + (gl_FragCoord.y * pixel_delta_v);
  vec3 ray_direction = pixel_center - camera_center;
  Ray ray = Ray(camera_center, ray_direction);

  vec3 pixel_color = ray_color(ray);
  gl_FragColor = vec4(pixel_color, 1.0);
}