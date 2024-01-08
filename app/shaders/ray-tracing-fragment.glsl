uniform vec2 u_resolution;
uniform float u_time;

const float infinity = 1000000.0;
const float pi = 3.14159265;

float degrees_to_radians(float degrees) {
  return degrees * pi / 180.0;
}

struct Ray {
  vec3 origin;
  vec3 direction;
};

struct IntersectionRecord {
  vec3 pos;
  vec3 normal;
  float t;
};

struct Sphere {
  vec3 center;
  float radius;
};

struct Triangle {
  vec3 p1;
  vec3 p2;
  vec3 p3;
};

struct Interval {
  float min, max;
};

bool interval_contains(Interval interval, float x) {
  return x >= interval.min && x <= interval.max;
}

bool interval_surrounds(Interval interval, float x) {
  return x > interval.min && x < interval.max;
}

Interval empty = Interval(+infinity, -infinity);
Interval universe = Interval(-infinity, +infinity);

vec3 ray_at(Ray ray, float t) {
  return ray.origin + t*ray.direction;
}

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


void main() {
  float aspect_ratio = 16.0 / 9.0;

  // camera
  float focal_length = 1.0;
  float viewport_height = 2.0;
  float viewport_width = viewport_height / (u_resolution.y/u_resolution.x);
  vec3 camera_center = vec3(0.0, 0.0, 0.0);

  vec3 viewport_u = vec3(viewport_width, 0.0, 0.0);
  vec3 viewport_v = vec3(0.0, viewport_height, 0.0);

  vec3 pixel_delta_u = viewport_u / u_resolution.x;
  vec3 pixel_delta_v = viewport_v / u_resolution.y;

  vec3 viewport_lower_left = camera_center - vec3(0.0, 0.0, focal_length) - viewport_u/2.0 - viewport_v/2.0;
  vec3 pixel00_loc = viewport_lower_left + 0.5 * (pixel_delta_u + pixel_delta_v);

  // vec2 st = gl_FragCoord.xy / u_resolution.xy;

  vec3 pixel_center = pixel00_loc + (gl_FragCoord.x * pixel_delta_u) + (gl_FragCoord.y * pixel_delta_v);
  vec3 ray_direction = pixel_center - camera_center;
  Ray ray = Ray(camera_center, ray_direction);

  vec3 pixel_color = ray_color(ray);
  gl_FragColor = vec4(pixel_color, 1.0);
}