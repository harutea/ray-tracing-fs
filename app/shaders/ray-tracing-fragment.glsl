uniform vec2 u_resolution;
uniform float u_time;

const float infinity = 1000000.0;
const float pi = 3.14159265;

// utility

float variation = 0.001;
float rand(vec2 co){
    variation += 0.001;
    return fract(sin(dot(co, vec2(12.9898+variation, 78.233+variation))) * 43758.5453);
}

float rand(vec2 co, float min, float max) {
  return min + (max-min)*rand(co);
}

vec3 rand_vec3(vec2 co) {
  return vec3(rand(co), rand(co), rand(co));
}

vec3 rand_vec3(vec2 co, float min, float max) {
  return vec3(rand(co, min, max), rand(co, min, max), rand(co, min, max));
}

float degrees_to_radians(float degrees) {
  return degrees * pi / 180.0;
}

struct Interval {
  float min, max;
};

bool interval_contains(Interval interval, float x) {
  return x >= interval.min && x <= interval.max;
}

bool interval_surrounds(Interval interval, float x) {
  return x > interval.min && x < interval.max;
}

float interval_clamp(Interval interval, float x) {
  if (x < interval.min) return interval.min;
  if (x > interval.max) return interval.max;
  return x;
}

Interval empty = Interval(+infinity, -infinity);
Interval universe = Interval(-infinity, +infinity);

struct Ray {
  vec3 origin;
  vec3 direction;
};

vec3 ray_at(Ray ray, float t) {
  return ray.origin + t*ray.direction;
}

struct IntersectionRecord {
  vec3 pos;
  vec3 normal;
  float t;
};

struct Sphere {
  vec3 center;
  float radius;
};

bool ray_sphere_intersection(Ray ray, Interval ray_t, Sphere s, inout IntersectionRecord record) {
  vec3 co = ray.origin - s.center;
  float a = dot(ray.direction, ray.direction);
  float half_b = dot(co, ray.direction);
  float c = dot(co, co) - s.radius*s.radius;
  
  float discriminant = half_b*half_b - a*c;
  if (discriminant < 0.0) {
    return false;
  }
  float sqrtd = sqrt(discriminant);

  float root = (-half_b - sqrtd) / a;
  if (!interval_surrounds(ray_t, root)) {
    root = (-half_b + sqrtd) / a;
    if (!interval_surrounds(ray_t, root))
      return false;
  }

  record.t = root;
  record.pos = ray_at(ray, record.t);
  record.normal = normalize(record.pos - s.center);
  return true;
}

struct Triangle {
  vec3 p1;
  vec3 p2;
  vec3 p3;
};

vec3 ray_color(Ray ray) {
  
  // world
  Sphere[] sphere_list = Sphere[](
    Sphere(vec3(0.0, 0.0, -1.0), 0.5),
    Sphere(vec3(0.0, -100.5, -1.0), 100.0)
  );

  IntersectionRecord record;
  IntersectionRecord rec_temp;
  bool intersect_something = false;
  float closest = infinity;
  
  for (int i=0; i<sphere_list.length(); i++) {
    bool intersect = ray_sphere_intersection(ray, Interval(0.0, closest), sphere_list[i], rec_temp);
    
    if(intersect) {
      intersect_something = true;
      closest = rec_temp.t;
      record = rec_temp;
    }
  }

  if(intersect_something) {
      return 0.5 * (record.normal + vec3(1.0, 1.0, 1.0));
  }

  // intersect with nothing
  vec3 unit_direction = normalize(ray.direction);
  float a = 0.5*(unit_direction.y + 1.0);
  return (1.0-a)*vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.7, 1.0);
}

struct Camera {
  float aspect_ratio;
  int samples_per_pixel;
  vec3 center;
  vec3 pixel_lower_left;
  vec3 pixel_delta_u;
  vec3 pixel_delta_v;
};

void init(inout Camera camera) {
  camera.aspect_ratio = u_resolution.y/u_resolution.x;
  camera.samples_per_pixel = 100;

  float focal_length = 1.0;
  float viewport_height = 2.0;
  float viewport_width = viewport_height / camera.aspect_ratio;
  camera.center = vec3(0.0, 0.0, 0.0);

  vec3 viewport_u = vec3(viewport_width, 0.0, 0.0);
  vec3 viewport_v = vec3(0.0, viewport_height, 0.0);

  camera.pixel_delta_u = viewport_u / u_resolution.x;
  camera.pixel_delta_v = viewport_v / u_resolution.y;

  vec3 viewport_lower_left = camera.center - vec3(0.0, 0.0, focal_length) - viewport_u/2.0 - viewport_v/2.0;
  camera.pixel_lower_left = viewport_lower_left + 0.5 * (camera.pixel_delta_u + camera.pixel_delta_v);
}

vec3 pixel_sample_square(Camera camera) {
  float px = -0.5 + rand(vec2(gl_FragCoord.xy));
  float py = -0.5 + rand(vec2(gl_FragCoord.xy));
  return (px * camera.pixel_delta_u) + (py * camera.pixel_delta_v);
}

Ray get_ray(Camera camera, float x, float y) {
  vec3 pixel_center = camera.pixel_lower_left + (x * camera.pixel_delta_u) + (y * camera.pixel_delta_v);
  vec3 pixel_sample = pixel_center + pixel_sample_square(camera);

  vec3 ray_direction = pixel_sample - camera.center;
  return Ray(camera.center, ray_direction);
}

void main() {
  Camera camera;
  init(camera);

  vec3 pixel_color = vec3(0.0, 0.0, 0.0);
  for(int sample_i = 0; sample_i < camera.samples_per_pixel; sample_i++) {
    Ray ray = get_ray(camera, gl_FragCoord.x, gl_FragCoord.y);
    pixel_color += ray_color(ray);
  }

  float scale = 1.0 / float(camera.samples_per_pixel);
  Interval intensity = Interval(0.000, 0.999);
  float cx = interval_clamp(intensity, pixel_color.x * scale);
  float cy = interval_clamp(intensity, pixel_color.y * scale);
  float cz = interval_clamp(intensity, pixel_color.z * scale);
  pixel_color = vec3(cx, cy, cz);
  gl_FragColor = vec4(pixel_color, 1.0);
}